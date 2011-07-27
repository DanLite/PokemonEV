//
//  TrackerViewController.m
//  PokemonEV
//
//  Created by Dan Lichty on 11-05-17.
//  Copyright 2011 Daniel Lichty. All rights reserved.
//

#import "TrackerViewController.h"
#import "SpeciesListViewController.h"
#import "Pokemon.h"
#import "PokemonSpecies.h"
#import "PokemonEncounter.h"
#import "PokemonStats.h"
#import "EVSpread.h"
#import "EVCountView.h"
#import "HeldItem.h"
#import "HeldItemListViewController.h"
#import "EVCountViewController.h"
#import "EVCountFooterCell.h"
#import "NSError+Multiple.h"
#import "PokemonSpeciesCell.h"
#import "PokemonListViewController.h"
#import "UseItemListViewController.h"
#import "Appirater.h"

NSInteger const PokerusActionSheetTag = 101;
NSInteger const UseItemActionSheetTag = 102;

@interface TrackerViewController()

- (void)presentPokemonListWithEVs:(BOOL)showEVYield;
- (void)refreshView;
- (void)updateEVCountViews;
- (void)loadRecentEncounters;
- (void)battledPokemon:(PokemonSpecies *)species indexPath:(NSIndexPath *)indexPath;
- (void)changeEVMode:(EVCountMode)mode;
- (void)cancelEditingEVs;

@end

@implementation TrackerViewController

@synthesize pokemon;
@synthesize evCountFooterCell;
@synthesize editingContext, editingEVSpread;
@synthesize recentEncounters;
@synthesize useItemListVC;

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context
{
	if ((self = [super initWithStyle:UITableViewStyleGrouped]))
	{
		managedObjectContext = [context retain];
    evViewControllers = [[NSMutableDictionary alloc] init];
    evMode = EVCountModeView;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(evCountInputChanged:) name:EVCountInputChanged object:nil];
	}
	
	return self;
}

- (id)initWithPokemon:(Pokemon *)pkmn
{
	if ((self = [self initWithManagedObjectContext:[pkmn managedObjectContext]]))
	{
		self.pokemon = pkmn;
		[self loadRecentEncounters];
	}
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	if (pokemon == nil && !LaunchImage)
	{
		[self presentPokemonListWithEVs:NO];
	}
	
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon-list"] style:UIBarButtonItemStyleBordered target:self action:@selector(listTapped)] autorelease];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon-envelope"] style:UIBarButtonItemStyleBordered target:self action:@selector(emailTapped)] autorelease];
  
  [self refreshView];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	if (changesFromConsumableItem)
	{
		[self updateEVCountViews];
		changesFromConsumableItem = NO;
	}
}

- (void)loadRecentEncounters
{
	self.recentEncounters = [managedObjectContext fetchAllObjectsForEntityName:[PokemonEncounter entityName]
																												 withSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]
																																andPredicate:[NSPredicate predicateWithFormat:@"pokemon == %@", pokemon]];
}

#pragma mark - Updating views

- (EVSpread *)activeEVSpread
{
  return (evMode == EVCountModeEditGoal) ? pokemon.goalSpread : pokemon.currentSpread;
}

- (void)updateEVCountViews
{
  for (NSNumber *statNumber in evViewControllers)
  {
    EVCountViewController *vc = [evViewControllers objectForKey:statNumber];
    vc.mode = evMode;
    
    PokemonStatID statID = [statNumber intValue];
    vc.current = [pokemon.currentSpread effortForStat:statID];
    vc.goal = [pokemon.goalSpread effortForStat:statID];
  }
  
  evCountFooterCell.goal = [pokemon.goalSpread totalEffort];
  evCountFooterCell.current = [pokemon.currentSpread totalEffort];
}

- (void)refreshView
{
	if (LaunchImage)
	{
		self.navigationItem.title = @"Loading...";
	}
	else if (pokemon)
	{
		self.navigationItem.title = pokemon.species.name;
	}
	else
	{
		self.navigationItem.title = @"";
		return;
	}
	
	HeldItem *item = pokemon.heldItem;
	
	TTButton *heldItemButton = [[[TTButton alloc] initWithFrame:CGRectMake(0, 0, 130, 33)] autorelease];
	[heldItemButton setStylesWithSelector:@"imageTitleToolbarButton:"];
	[heldItemButton addTarget:self action:@selector(heldItemButtonTapped) forControlEvents:UIControlEventTouchUpInside];
	
	if (item)
	{
		[heldItemButton setTitle:item.name forState:UIControlStateNormal];
	}
	else
	{
		[heldItemButton setTitle:@"No held item" forState:UIControlStateNormal];
	}
	
	[pokerusButton release];
	pokerusButton = [[TTButton alloc] initWithFrame:CGRectMake(0, 0, 50, 33)];
	[pokerusButton setStylesWithSelector:@"pokerusButton:"];
	[pokerusButton setTitle:@"PKRS" forState:UIControlStateNormal];
	[pokerusButton addTarget:self action:@selector(pokerusTapped:) forControlEvents:UIControlEventTouchUpInside];
	pokerusButton.selected = pokemon.pokerusValue;
	
	TTButton *useItemButton = [TTButton buttonWithStyle:@"toolbarButton:" title:@"Use Item"];
	useItemButton.frame = CGRectMake(0, 0, 72, 33);
	[useItemButton addTarget:self action:@selector(useItemButtonTapped) forControlEvents:UIControlEventTouchUpInside];
	
	UIBarButtonItem *heldItemButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:heldItemButton] autorelease];
	UIBarButtonItem *pokerusButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:pokerusButton] autorelease];
	UIBarButtonItem *itemButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:useItemButton] autorelease];
	self.toolbarItems = [NSArray arrayWithObjects:heldItemButtonItem, FlexibleSpace, pokerusButtonItem, FlexibleSpace, itemButtonItem, nil];
}

- (void)showPokerusActionSheet:(BOOL)applyPokerus
{
	NSString *action = [NSString stringWithFormat:@"%@ Pokérus", applyPokerus ? @"Apply" : @"Remove"];
	
	UIActionSheet *sheet = [[UIActionSheet alloc]
													initWithTitle:@"When your Pokémon is affected by Pokérus, it gains twice as many EVs from battling."
													delegate:self
													cancelButtonTitle:@"Cancel"
													destructiveButtonTitle:nil
													otherButtonTitles:action, nil];
	sheet.tag = PokerusActionSheetTag;
	
	[sheet showFromToolbar:self.navigationController.toolbar];
	[sheet release];
}

- (void)cancelEditingEVs
{
  self.editingEVSpread = nil;
  self.editingContext = nil;
  
  [self changeEVMode:EVCountModeView];
}

#pragma mark - Action sheet delegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (actionSheet.tag == PokerusActionSheetTag)
	{
		if (buttonIndex != actionSheet.cancelButtonIndex)
		{
			BOOL newValue = !pokerusButton.selected;
			
			pokemon.pokerusValue = newValue;
			[pokemon setModified];
			
			NSError *error;
			if (![managedObjectContext save:&error])
			{
				DLog(@"Unable to set Pokerus status: %@", error);
				[managedObjectContext rollback];
			}
			
			pokerusButton.selected = newValue;
		}
	}
	else if (actionSheet.tag == UseItemActionSheetTag)
	{
		if (buttonIndex != actionSheet.cancelButtonIndex)
		{
			self.useItemListVC = [[UseItemListViewController alloc] initWithItemType:buttonIndex pokemon:pokemon];
			[[NSNotificationCenter defaultCenter] addObserver:self
																							 selector:@selector(editingContextDidSave:)
																									 name:NSManagedObjectContextDidSaveNotification
																								 object:useItemListVC.managedObjectContext];
			[self.navigationController pushViewController:useItemListVC animated:YES];
			[useItemListVC release];
		}
	}
}

#pragma mark - Notifications

- (void)editingContextDidSave:(NSNotification *)note
{
	NSManagedObjectContext *otherContext = [note object];
	
	if (otherContext == useItemListVC.managedObjectContext)
	{
		changesFromConsumableItem = YES;
	}
	
	[managedObjectContext mergeChangesFromContextDidSaveNotification:note];
	
	[pokemon setModified];
	[managedObjectContext save:nil];
}

- (void)evCountInputChanged:(NSNotification *)note
{
  EVCountViewController *countVC = [note object];
  EVCountMode mode = countVC.mode;
  PokemonStatID stat = countVC.statID;
  NSInteger newValue = [(NSNumber *)[[note userInfo] objectForKey:@"newValue"] intValue];
  
  if (mode == EVCountModeEditGoal)
  {
    countVC.goal = newValue;
    [self.editingEVSpread setEffort:newValue forStat:stat];
    evCountFooterCell.goal = [editingEVSpread totalEffort];
  }
  else if (mode == EVCountModeEditCurrent)
  {
    countVC.current = newValue;
    [self.editingEVSpread setEffort:newValue forStat:stat];
    evCountFooterCell.current = [editingEVSpread totalEffort];
  }
}

#pragma mark - Event handlers

- (void)listTapped
{
	[self cancelEditingEVs];
	
	PokemonListViewController *listVC = [[PokemonListViewController alloc] initWithManagedObjectContext:managedObjectContext];
	listVC.delegate = self;
	listVC.currentPokemon = pokemon;
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:listVC];
	[self.navigationController presentModalViewController:navController animated:YES];
	[navController release];
	[listVC release];
}

- (void)pokerusTapped:(UIButton *)button
{
	[self showPokerusActionSheet:!button.selected];
}

- (void)useItemButtonTapped
{
	NSString *title = [NSString stringWithFormat:@"Use an item on %@:", pokemon.species.name];
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:title delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Berries", @"Vitamins", @"Wings", nil];
	sheet.tag = UseItemActionSheetTag;
	
	[sheet showFromToolbar:self.navigationController.toolbar];
}

- (void)heldItemButtonTapped
{
  HeldItemListViewController *listVC = [[HeldItemListViewController alloc] initWithManagedObjectContext:managedObjectContext];
  listVC.delegate = self;
  UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:listVC];
  [self.navigationController presentModalViewController:navController animated:YES];
  [navController release];
  [listVC release];
}

- (void)changeEVMode:(EVCountMode)mode
{
  evMode = mode;
  
  if (evMode != EVCountModeView)
  {
    self.editingContext = [[NSManagedObjectContext alloc] init];
    [editingContext setPersistentStoreCoordinator:[managedObjectContext persistentStoreCoordinator]];
    
    EVSpread *thisSpread = (evMode == EVCountModeEditCurrent) ? pokemon.currentSpread : pokemon.goalSpread;
    self.editingEVSpread = [editingContext
                            fetchSingleObjectForEntityName:[EVSpread entityName]
                            withPredicate:[NSPredicate predicateWithFormat:@"SELF == %@", thisSpread]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editingContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:editingContext];
  }
	
	[self updateEVCountViews];
  
  evCountFooterCell.mode = evMode;
}

- (void)evDoneTapped
{
  NSError *error;
  if (![editingContext save:&error])
  {
    [[[[UIAlertView alloc]
       initWithTitle:@"Invalid Numbers"
       message:[[error allFailureReasons] componentsJoinedByString:@" "]
       delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]
      autorelease]
     show];
    return;
  }
	
	[self cancelEditingEVs];
}

- (void)evCurrentTapped
{
  [self changeEVMode:EVCountModeEditCurrent];
}

- (void)evGoalTapped
{
  [self changeEVMode:EVCountModeEditGoal];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section)
	{
		case 0:
			return 2;
		case 1:
			return 1 + [recentEncounters count];
	}
	
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0)
	{
    if (indexPath.row == 0)
    {
			static NSString *EVCountCellIdentifier = @"EVCountCellIdentifier";
      UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:EVCountCellIdentifier];
			if (cell == nil)
			{
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:EVCountCellIdentifier] autorelease];
				cell.selectionStyle = UITableViewCellSelectionStyleNone;
				
				TTGridLayout *grid = [[TTGridLayout alloc] init];
				grid.columnCount = 3;
				grid.spacing = 0;
				grid.padding = 0;
				
				TTView *evTable = [[TTView alloc] initWithFrame:CGRectMake(0, 0, 300, 80)];
				evTable.layout = grid;
				evTable.backgroundColor = [UIColor clearColor];
				
				for (int i = PokemonStatFirst; i <= PokemonStatLast; i++)
				{
					EVCountViewController *countVC = [[EVCountViewController alloc] initWithStatID:i];
					if (evMode != EVCountModeView)
						countVC.textField.alpha = 1;
					
					countVC.mode = evMode;
					countVC.goal = [pokemon.goalSpread effortForStat:i];
					countVC.current = [pokemon.currentSpread effortForStat:i];
					
					[evTable addSubview:countVC.view];
					[evViewControllers setObject:countVC forKey:[NSNumber numberWithInt:i]];
					[countVC release];
				}
				
				[cell.contentView addSubview:evTable];
			}
      
      return cell;
    }
    if (indexPath.row == 1)
    {
      if (self.evCountFooterCell == nil)
      {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([EVCountFooterCell class]) owner:nil options:nil];
        self.evCountFooterCell = [nib objectAtIndex:0];
        
        evCountFooterCell.mode = evMode;
        evCountFooterCell.goal = [pokemon.goalSpread totalEffort];
        evCountFooterCell.current = [pokemon.currentSpread totalEffort];
      }
      
      return self.evCountFooterCell;
    }
	}
	
	if (indexPath.section == 1)
	{
		if (indexPath.row == 0)
		{
			UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
			cell.textLabel.text = @"Battled new Pokémon";
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			
			return cell;
		}
		else
		{
			NSInteger index = indexPath.row - 1;
			PokemonEncounter *encounter = [recentEncounters objectAtIndex:index];
			
			static NSString *SpeciesCellIdentifier = @"SpeciesCell";
			
			PokemonSpeciesCell *cell = (PokemonSpeciesCell *)[tableView dequeueReusableCellWithIdentifier:SpeciesCellIdentifier];
			if (cell == nil)
			{
				cell = [[[PokemonSpeciesCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:SpeciesCellIdentifier] autorelease];
				cell.showEVYield = YES;
			}
			
			[cell setPokemon:encounter.species filteredStat:nil];
			
			NSInteger encounterCount = encounter.countValue;
			cell.detailTextLabel.text = [NSString stringWithFormat:@"Battled %d time%@",
																	 encounterCount,
																	 (encounterCount == 1) ? @"" : @"s"];
			
			return cell;
		}
	}
	
	return nil;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete)
	{
		NSInteger index = indexPath.row - 1;
		PokemonEncounter *encounter = [recentEncounters objectAtIndex:index];
		
		[managedObjectContext deleteObject:encounter];
		[pokemon setModified];
		
		NSError *error;
		if (![managedObjectContext save:&error])
		{
			DLog(@"Unable to remove encounter: %@", error);
			[managedObjectContext rollback];
			return;
		}
		
		[self loadRecentEncounters];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
	}
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 1 && indexPath.row == 0)
	{
		[self presentPokemonListWithEVs:YES];
	}
	else if (indexPath.section == 1)
	{
		PokemonEncounter *encounter = [recentEncounters objectAtIndex:indexPath.row - 1];
		[self battledPokemon:encounter.species indexPath:indexPath];
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0 && indexPath.row == 0)
		return 80;
	
	return 44;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0)
		cell.backgroundView = nil;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 1 && indexPath.row > 0)
	{
		return UITableViewCellEditingStyleDelete;
	}
	
	return UITableViewCellEditingStyleNone;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"Remove";
}

#pragma mark - Held item list

- (void)heldItemList:(HeldItemListViewController *)listVC choseItem:(HeldItem *)item
{
	[self.navigationController dismissModalViewControllerAnimated:YES];
  
  pokemon.heldItem = item;
	[pokemon setModified];
  
  NSError *error;
  if (![managedObjectContext save:&error])
  {
    DLog(@"Unable to set held item: %@", error);
    [managedObjectContext rollback];
		return;
  }
  
  [self refreshView];
}

#pragma mark - Pokemon list

- (void)pokemonList:(PokemonListViewController *)listVC chosePokemon:(Pokemon *)aPokemon
{
	[self.navigationController dismissModalViewControllerAnimated:YES];
	
	self.pokemon = aPokemon;
	[self loadRecentEncounters];
	[self refreshView];
	[self.tableView reloadData];
	[self updateEVCountViews];
}

#pragma mark - Species list

- (void)battledPokemon:(PokemonSpecies *)species indexPath:(NSIndexPath *)indexPath
{
	PokemonEncounter *encounter = [managedObjectContext
																 fetchSingleObjectForEntityName:[PokemonEncounter entityName]
																 withPredicate:[NSPredicate predicateWithFormat:@"pokemon == %@ AND species == %@", pokemon, species]];
	
	BOOL createdEncounter = NO;
	if (encounter == nil)
	{
		encounter = [PokemonEncounter insertInManagedObjectContext:managedObjectContext];
		encounter.pokemon = pokemon;
		encounter.species = species;
		createdEncounter = YES;
	}
	
	encounter.countValue += 1;
	encounter.date = [NSDate date];
	
	if (indexPath == nil)
	{
		if (createdEncounter)
		{
			indexPath = [NSIndexPath indexPathForRow:1 inSection:1];
		}
		else
		{
			NSInteger row = 1;
			for (PokemonEncounter *anEncounter in recentEncounters)
			{
				if ([anEncounter isEqual:encounter])
					break;
				row++;
			}
			indexPath = [NSIndexPath indexPathForRow:row inSection:1];
		}
	}
	
	[self loadRecentEncounters];
	
	[self.tableView beginUpdates];
	if (createdEncounter)
	{
		[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationRight];
	}
	else if (indexPath.row == 1)
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
		[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
	else
	{
		[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
		[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:1]] withRowAnimation:UITableViewRowAnimationRight];
	}
	[self.tableView endUpdates];
	
	[pokemon setModified];
	
	// Save encounter
	[managedObjectContext save:nil];
	
	// If this fails, the MOC will be rolled back to the previous state, and it will return an empty NSDictionary
	NSDictionary *earnedEVs = [pokemon addEffortFromPokemon:species];
	
	// Save EV change
	[managedObjectContext save:nil];
	
	// If it earned EVs and has either reached the total limit of EVs or reached its EV goals
	if (([earnedEVs count] > 0) && ([pokemon.currentSpread totalEffort] == MaximumStatEVCount || [pokemon.currentSpread matchesSpread:pokemon.goalSpread]))
	{
		[self performSelector:@selector(notifySignificantEvent) withObject:nil afterDelay:1];
	}
	
	[self cancelEditingEVs];
	
	for (NSNumber *statKey in earnedEVs)
	{
		EVCountViewController *countVC = [evViewControllers objectForKey:statKey];
		[countVC animatePulseWithValue:[[earnedEVs objectForKey:statKey] intValue]];
	}
	
	[self updateEVCountViews];
}

- (void)notifySignificantEvent
{
	[Appirater userDidSignificantEvent:YES];
}

- (void)presentPokemonListWithEVs:(BOOL)showEVYield
{
	SpeciesListViewController *listVC = [[SpeciesListViewController alloc] initWithManagedObjectContext:managedObjectContext];
	listVC.delegate = self;
	listVC.showEVYield = showEVYield;
	listVC.allowsClose = showEVYield;
	
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:listVC];
	navController.toolbarHidden = NO;
	
	[self.navigationController presentModalViewController:navController animated:YES];
	
	[navController release];
	[listVC release];
	
	[self cancelEditingEVs];
}

- (void)speciesList:(SpeciesListViewController *)listVC choseSpecies:(PokemonSpecies *)species
{
	[self.navigationController dismissModalViewControllerAnimated:YES];
	
	if (species == nil)
		return;
	
	if (listVC.showEVYield)
	{
		[self battledPokemon:species indexPath:nil];
	}
	else
	{
		// This only happens the when the user launches the app with no saved Pokemon (e.g. first time)
		Pokemon *newPokemon = [Pokemon insertFromSpecies:species inManagedObjectContext:managedObjectContext];
		
		self.pokemon = newPokemon;
		[self loadRecentEncounters];
		[self refreshView];
    
    NSError *error;
    if (![managedObjectContext save:&error])
    {
      DLog(@"Unable to create new Pokemon: %@", error);
      [managedObjectContext rollback];
    }
	}
}

#pragma mark - Email

- (void)emailTapped
{
	if (![MFMailComposeViewController canSendMail])
	{
		[[[[UIAlertView alloc] initWithTitle:@"Cannot Send Email" message:@"Email is not set up on this device." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];
		return;
	}
	
	MFMailComposeViewController *composer = [[MFMailComposeViewController alloc] init];
	[composer setMailComposeDelegate:self];
	
	[composer setSubject:[NSString stringWithFormat:@"%@ Feedback", [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey]]];
	[composer setToRecipients:[NSArray arrayWithObject:@"dan@appsbydan.com"]];
	
	[self.navigationController presentModalViewController:composer animated:YES];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	if (result == MFMailComposeResultFailed)
	{
		[[[[UIAlertView alloc] initWithTitle:@"Email Failed" message:@"There was an error sending your email. Please try again later." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];
	}
	
	[self.navigationController dismissModalViewControllerAnimated:YES];
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	// Releases the view if it doesn't have a superview.
	[super didReceiveMemoryWarning];

	// Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload
{
	[super viewDidUnload];
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
	[useItemListVC release];
	[recentEncounters release];
	[pokerusButton release];
  [editingContext release];
  [editingEVSpread release];
  [evViewControllers release];
  [evCountFooterCell release];
  [managedObjectContext release];
  [pokemon release];
	[super dealloc];
}


@end
