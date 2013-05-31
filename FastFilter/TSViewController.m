//
//  TSViewController.m
//  FastFilter
//
//  Created by Nicholas Hodapp on 5/31/13.
//  Copyright (c) 2013 Nicholas Hodapp. All rights reserved.
//

#import "TSViewController.h"

@interface TSViewController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation TSViewController
{
    IBOutlet UIActivityIndicatorView*   _activityIndicatorView;
    
    NSArray*                            _allWords;
    
    NSArray*                            _filteredWords;
    
    NSString*                           _currentFilter;
    
    dispatch_queue_t                    _workQueue;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    _workQueue = dispatch_queue_create( "com.codeveloper.fastfilter", DISPATCH_QUEUE_SERIAL);
    
    [self loadWords];
}

- (BOOL) searchDisplayController: (UISearchDisplayController *) controller
shouldReloadTableForSearchString: (NSString *) filter
{
    // we'll key off the _currentFilter to know if the search should proceed
    @synchronized (self)
    {
        _currentFilter = [filter copy];
    }
    
    dispatch_async( _workQueue, ^{
        
        NSDate* start = [NSDate date];

        // quit before we even begin?
        if ( ![self isCurrentFilter: filter] )
            return;
        
        // we're going to search, so show the indicator (may already be showing)
        [_activityIndicatorView performSelectorOnMainThread: @selector( startAnimating )
                                                 withObject: nil
                                              waitUntilDone: NO];
        
        NSMutableArray* filteredWords = [NSMutableArray arrayWithCapacity: _allWords.count];
        
        // only using a NSPredicate here because of the SO question...
        NSPredicate* p = [NSPredicate predicateWithFormat: @"SELF CONTAINS[cd] %@", filter];
        
        // this is a slow search... scan every word using the predicate!
        [_allWords enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
           
            // check if we need to bail every so often:
            if ( idx % 100 == 0 )
            {
                *stop = ![self isCurrentFilter: filter];
                if (*stop)
                {
                    NSTimeInterval ti = [start timeIntervalSinceNow];
                    NSLog( @"interrupted search after %.4lf seconds", -ti);
                    return;
                }
            }
            
            // check for a match
            if ( [p evaluateWithObject: obj] )
            {
                [filteredWords addObject: obj];
            }
        }];
        
        // all done - if we're still current then update the UI
        if ( [self isCurrentFilter: filter] )
        {
            NSTimeInterval ti = [start timeIntervalSinceNow];
            NSLog( @"completed search in %.4lf seconds.", -ti);

            dispatch_sync( dispatch_get_main_queue(), ^{
                
                _filteredWords = filteredWords;
                [controller.searchResultsTableView reloadData];
                [_activityIndicatorView stopAnimating];
            });
        }
    });
    
    return FALSE;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_filteredWords count];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* tvc = [tableView dequeueReusableCellWithIdentifier: @"cell"];
    if ( tvc == nil )
    {
        [tableView registerClass: [UITableViewCell class] forCellReuseIdentifier: @"cell"];
        tvc = [tableView dequeueReusableCellWithIdentifier: @"cell"];
        NSParameterAssert( tvc );
    }
    
    tvc.textLabel.text = [_filteredWords objectAtIndex: indexPath.row];
    
    return tvc;
}

- (BOOL) isCurrentFilter: (NSString*) filter
{
    @synchronized (self)
    {
        // are we current at this point?
        BOOL current = [_currentFilter isEqualToString: filter];
        return current;
    }
}

- (void) loadWords
{
    UIAlertView* loadingAlertView = [[UIAlertView alloc] initWithTitle: @"Loading Dictionary..."
                                                               message: nil
                                                              delegate: nil
                                                     cancelButtonTitle: nil
                                                     otherButtonTitles: nil];
    
    [loadingAlertView show];

    dispatch_async( _workQueue, ^{
       
        NSURL* url = [[NSBundle mainBundle] URLForResource: @"web2" withExtension: @""];
        NSString* dict = [NSString stringWithContentsOfURL: url
                                                  encoding: NSUTF8StringEncoding error: nil];
        
        _allWords = [dict componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];

        dispatch_async( dispatch_get_main_queue(), ^{
            
            [loadingAlertView dismissWithClickedButtonIndex: 0 animated: YES];
        });
    });
}

@end
