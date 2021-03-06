//
//  ViewController.m
//  Weathr
//
//  Created by Paul Williamson on 17/10/2013.
//  Copyright (c) 2013 Paul Williamson. All rights reserved.
//

#import "ViewController.h"

#import "OpenWeatherAPIManager.h"
#import "PWTemperatureConversion.h"
#import "WeatherDescriptionBuilder.h"
#import "WeatherModel.h"

#import <CoreLocation/CoreLocation.h>
#import <QuartzCore/QuartzCore.h>

#define ANIMATION_DURATION 1.0f

#define COOL_THRESHOLD   10.0f
#define WARM_THRESHOLD   18.0f
#define HOT_THRESHOLD    27.0f

@interface ViewController () <WeatherModelDelegate,OpenWeatherAPIManagerDelegate,CLLocationManagerDelegate>

@property (nonatomic, weak) IBOutlet UIImageView *weatherIcon;
@property (nonatomic, weak) IBOutlet UILabel *weatherDescription;
@property (nonatomic, weak) IBOutlet UILabel *lastUpdatedLabel;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, weak) IBOutlet UIButton *refreshButton;

@property (nonatomic, strong) WeatherModel *weatherModel;
@property (nonatomic, strong) OpenWeatherAPIManager *apiManager;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSDate *appStartDate;
@property (nonatomic, strong) Class alertViewClass;

@property (nonatomic, strong) CLLocation *bestEffortLocation;

@end

@implementation ViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _alertViewClass = [UIAlertView class];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _weatherModel = [[WeatherModel alloc] init];
    _weatherModel.delegate = self;
    
    _apiManager = [[OpenWeatherAPIManager alloc] init];
    _apiManager.delegate = self;
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
    
    _appStartDate = [NSDate date];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self fetchLocation];
}


#pragma mark - UI Updates
- (void)updateWeatherIcon: (NSString *)imageName
{
    [_weatherIcon.layer addAnimation:[self animationStyle] forKey:nil];
    _weatherIcon.image = [UIImage imageNamed:imageName];
}

- (void)updateWeatherDescription: (NSAttributedString *)description
{
    [_weatherDescription.layer addAnimation:[self animationStyle] forKey:nil];
    _weatherDescription.attributedText = description;
}

- (void)updateLastUpdatedLabel: (NSString *)lastUpdated
{
    [_lastUpdatedLabel.layer addAnimation:[self animationStyle] forKey:nil];
    _lastUpdatedLabel.text = [NSString stringWithFormat:@"Last updated: %@", lastUpdated];
}

- (CATransition *)animationStyle
{
    CATransition *transition = [CATransition animation];
    transition.duration = ANIMATION_DURATION;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transition.type = kCATransitionFade;
    return transition;
}

- (void)reloadView
{
    if (_weatherModel)
    {
        [self updateWeatherIcon:_weatherModel.icon];
        NSMutableAttributedString *description = [WeatherDescriptionBuilder detailedWeatherDescriptionFromModel:_weatherModel];
        [self updateWeatherDescription:description];
        [self updateLastUpdatedLabel:[WeatherModel parseDate:_weatherModel.lastUpdated]];
        float t = [PWTemperatureConversion kelvinToCelsius:[_weatherModel.temperature floatValue]];
        [self changeBackgroundColourWithTemperature:t];
    }
    [self stopActivityIndicator];
}

#pragma mark - Activity indicator
- (void)startActivityIndicator
{
    [_activityIndicator startAnimating];
}

- (void)stopActivityIndicator
{
    [_activityIndicator stopAnimating];
}

#pragma mark - View background colour
- (void)changeBackgroundColourWithTemperature: (float)temp
{
    UIColor *colour = [self colourForTemperature:temp];
    
    [self.view.layer addAnimation:[self animationStyle] forKey:nil];
    self.view.backgroundColor = colour;
}

- (UIColor *)colourForTemperature: (float)temp
{
    if (temp >= COOL_THRESHOLD &&
        temp < WARM_THRESHOLD)
        return COLOUR_COOL;
    
    else if (temp >= WARM_THRESHOLD &&
             temp < HOT_THRESHOLD)
        return COLOUR_WARM;
    
    else if (temp >= HOT_THRESHOLD)
        return COLOUR_HOT;
    
    return COLOUR_COLD;
}


#pragma mark - Alerts
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message
{
    [[[_alertViewClass alloc] initWithTitle:title
                                    message:message
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
}


#pragma mark - Weather model delegate
- (void)weatherModelUpdated
{
    [self reloadView];
}


#pragma mark - API manager delegate
- (void)downloadWeatherDataWithLocation:(CLLocation *)newLocation
{
    [_apiManager updateURLWithLocation:newLocation];
    [_apiManager fetchWeatherData];
}

- (void)dataTaskSuccessWithData:(NSData *)data
{
    if (data) {
        [_weatherModel updateWeatherModelFromNSData:data];
    } else {
        [self downloadTaskFailed:nil];
    }
}

- (void)dataTaskFailWithHTTPURLResponse:(NSHTTPURLResponse *)response
{
    [self resetUIForFailure];
    [self downloadTaskFailed:response];
}

- (void)resetUIForFailure
{
    _lastUpdatedLabel.text = @"Error fetching weather report";
    _weatherDescription.attributedText = nil;
    [self showRefreshButton];
    [self stopActivityIndicator];
}

- (void)downloadTaskFailed:(NSHTTPURLResponse *)response
{
    [self showAlertWithTitle:@"Error downloading weather"
                     message:[self failedDownloadMessage:response]];
}

- (NSString *)failedDownloadMessage:(NSHTTPURLResponse *)response
{
    if (response)
        return @"The server returned an error, please try again later";
    
    else
        return @"Please check your network connection, and ensure your device is not in airplane mode";
}


#pragma mark - Core Location
- (void)fetchLocation
{
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized ||
        [CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined)
    {
        [_activityIndicator startAnimating];
        [_locationManager startUpdatingLocation];
        [self performSelector:@selector(stopUpdatingLocation:) withObject:@"Location fetch timed out" afterDelay:30.0f];
    }
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    NSTimeInterval locationAge = -[newLocation.timestamp timeIntervalSinceNow];
    if (locationAge > 5) return;
    
    if (_bestEffortLocation == nil ||
        _bestEffortLocation.horizontalAccuracy > newLocation.horizontalAccuracy)
    {
        self.bestEffortLocation = newLocation;
        
        if (newLocation.horizontalAccuracy <= manager.desiredAccuracy)
        {
            [manager stopUpdatingLocation];
            [NSObject cancelPreviousPerformRequestsWithTarget:self];
            [self downloadWeatherDataWithLocation:newLocation];
        }
    }
}

- (void)stopUpdatingLocation:(NSString *)message
{
    _activityIndicator.hidden = YES;
    [self showAlertWithTitle:@"Error fetching location" message:message];
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
    [_locationManager stopUpdatingLocation];
    [self locationUpdateFailed:error];
    [self resetUIForFailure];
}

- (void)locationUpdateFailed:(NSError *)error
{
    [self showAlertWithTitle:@"Error fetching location"
                     message:[self locationErrorMessage:error]];
}

- (NSString *)locationErrorMessage:(NSError *)error
{
    switch (error.code) {
        case kCLErrorNetwork:
            return @"Please check your network connection, and ensure your device is not in airplane mode";
            break;
        case kCLErrorDenied:
            return @"Please ensure location services is enabled for Weathr";
            break;
        default:
            return @"Please try again later";
            break;
    }
}

#pragma mark - Refresh button
- (IBAction)refreshButtonTapped:(id)sender
{
    if (_weatherModel.location)
        [self downloadWeatherDataWithLocation:_weatherModel.location];
    else
        [self fetchLocation];
    
    [self hideRefreshButton];
}

- (void)showRefreshButton
{
    [_refreshButton.layer addAnimation:[self animationStyle] forKey:nil];
    _refreshButton.hidden = NO;
}

- (void)hideRefreshButton
{
    [_refreshButton.layer addAnimation:[self animationStyle] forKey:nil];
    _refreshButton.hidden = YES;
}

@end
