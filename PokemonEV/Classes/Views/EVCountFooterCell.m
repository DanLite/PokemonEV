//
//  EVCountFooterCell.m
//  PokemonEV
//
//  Created by Dan Lichty on 11-05-22.
//  Copyright 2011 Daniel Lichty. All rights reserved.
//

#import "EVCountFooterCell.h"

@interface EVCountFooterCell()

- (void)updateEVTotalLabel;
- (void)updateTitleLabel;

@end


@implementation EVCountFooterCell

@synthesize mode, goal, current;
@synthesize titleLabel, evTotalLabel;

- (void)awakeFromNib
{
  mode = EVCountModeView;
  
  TTView *backgroundView = [[TTView alloc] initWithFrame:CGRectMake(0, 0, 300, 44)];
  backgroundView.style =
  [TTShapeStyle styleWithShape:[TTRoundedRectangleShape shapeWithTopLeft:0 topRight:0 bottomRight:10 bottomLeft:10] next:
   [TTBevelBorderStyle styleWithHighlight:[UIColor lightGrayColor] shadow:[UIColor grayColor] width:1 lightSource:305 next:
    [TTSolidFillStyle styleWithColor:[UIColor whiteColor] next:nil]]];
  backgroundView.opaque = NO;
  backgroundView.backgroundColor = [UIColor clearColor];
  
  [self.contentView insertSubview:backgroundView atIndex:0];
  
  CGFloat buttonY = 5;
  CGFloat buttonHeight = 35;
  
  currentButton = [[TTButton alloc] initWithFrame:CGRectMake(10, buttonY, 70, buttonHeight)];
  [currentButton setTitle:@"Current" forState:UIControlStateNormal];
  [currentButton setStylesWithSelector:@"midGrayToolbarButton:"];
  [currentButton addTarget:nil action:@selector(evCurrentTapped) forControlEvents:UIControlEventTouchUpInside];
  
  goalButton = [[TTButton alloc] initWithFrame:CGRectMake(10 + 70 + 10, buttonY, 70, buttonHeight)];
  [goalButton setTitle:@"Goal" forState:UIControlStateNormal];
  [goalButton setStylesWithSelector:@"midGrayToolbarButton:"];
  [goalButton addTarget:nil action:@selector(evGoalTapped) forControlEvents:UIControlEventTouchUpInside];
  [self.contentView addSubview:goalButton];
  [self.contentView addSubview:currentButton];
  
  doneButton = [[TTButton alloc] initWithFrame:CGRectMake(150, buttonY, 55, buttonHeight)];
  [doneButton setTitle:@"Save" forState:UIControlStateNormal];
  [doneButton setStylesWithSelector:@"blackToolbarButton:"];
  [doneButton addTarget:nil action:@selector(evDoneTapped) forControlEvents:UIControlEventTouchUpInside];
  doneButton.alpha = 0;
  [self.contentView addSubview:doneButton];
  
  [self updateEVTotalLabel];
  [self updateTitleLabel];
}

- (void)updateEVTotalLabel
{
  if (mode == EVCountModeView)
  {
    evTotalLabel.text = [NSString stringWithFormat:@"%d / %d", current, goal];
  }
  else
  {
    NSInteger value = (mode == EVCountModeEditGoal) ? goal : current;
    evTotalLabel.text = [NSString stringWithFormat:@"%d", value];
  }
}

- (void)updateTitleLabel
{
  if (mode == EVCountModeView)
  {
    titleLabel.text = @"";
  }
  else if (mode == EVCountModeEditGoal)
  {
    titleLabel.text = @"Editing EV goals";
  }
  else if (mode == EVCountModeEditCurrent)
  {
    titleLabel.text = @"Editing current EVs";
  }
}

- (void)setMode:(EVCountMode)aMode
{
  if (aMode == mode)
    return;
  
  mode = aMode;
  
  [self updateEVTotalLabel];
  [self updateTitleLabel];
  
  BOOL edit = (mode != EVCountModeView);
  [UIView animateWithDuration:0.3 animations:^(void)
   {
     titleLabel.alpha = edit ? 1 : 0;
     doneButton.alpha = edit ? 1 : 0;
     goalButton.alpha = edit ? 0 : 1;
     currentButton.alpha = edit ? 0 : 1;
   }];
}

- (void)setGoal:(NSInteger)aGoal
{
  if (aGoal == goal)
    return;
  
  goal = aGoal;
  
  [self updateEVTotalLabel];
}

- (void)setCurrent:(NSInteger)aCurrent
{
  if (aCurrent == current)
    return;
  
  current = aCurrent;
  
  [self updateEVTotalLabel];
}

- (void)dealloc
{
  [titleLabel release];
  [evTotalLabel release];
  [super dealloc];
}

@end
