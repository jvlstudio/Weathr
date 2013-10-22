//
//  WeatherModelTests.m
//  Weathr
//
//  Created by Paul Williamson on 17/10/2013.
//  Copyright (c) 2013 Paul Williamson. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WeatherModel.h"
#import "WeatherModel+PrivateMethods.h"
#import "WeatherModelExtensions.h"
#import <CoreLocation/CoreLocation.h>

@interface WeatherModelTests : XCTestCase <WeatherModelDelegate> {
    NSData *data;
    WeatherModel *model;
    NSDictionary *parsedData;
    BOOL callbackInvoked;
}

@end

@implementation WeatherModelTests

- (void)setUp
{
    [super setUp];
    data = [WeatherModelExtensions loadJSONFromFile];
    model = [[WeatherModel alloc] init];
    parsedData = (NSDictionary *)[WeatherModel parseJSONData:data];
}

- (void)tearDown
{
    data = nil;
    model = nil;
    parsedData = nil;
    [super tearDown];
}

#pragma mark - Properties
- (void)testModelHasWeatherDescriptionProperty
{
    XCTAssertTrue([WeatherModel instancesRespondToSelector:@selector(weatherDescription)], @"weatherDescription property does not exist on weather model class");
}

- (void)testModelHasTemperatureProperty
{
    XCTAssertTrue([WeatherModel instancesRespondToSelector:@selector(temperature)], @"temperature property does not exist on weather model class");
}

- (void)testModelHasIconProperty
{
    XCTAssertTrue([WeatherModel instancesRespondToSelector:@selector(icon)], @"icon property does not exist on weather model class");
}

- (void)testModelHasLocationNameProperty
{
    XCTAssertTrue([WeatherModel instancesRespondToSelector:@selector(locationName)], @"locationName property does not exist on weather model class");
}

- (void)testModelHasLastUpdatedProperty
{
    XCTAssertTrue([WeatherModel instancesRespondToSelector:@selector(lastUpdated)], @"lastUpdated property does not exist on weather model class");
}

- (void)testModelHasLocationProperty
{
    XCTAssertTrue([WeatherModel instancesRespondToSelector:@selector(location)], @"Location property does not exist on weather model class");
}


#pragma mark - Temperature

- (void)testTemperatureConversionKelvin
{
    NSNumber *kelvin = [NSNumber numberWithFloat:284.94];
    NSNumber *celsius = [WeatherModel convertKelvinToCelsius: kelvin];
    NSNumber *expected = [NSNumber numberWithFloat:11.79];
    XCTAssertEqualWithAccuracy([celsius floatValue], [expected floatValue], 0.00001, @"Kelvin conversion should equal %f, got %f", [expected floatValue], [celsius floatValue]);
}


- (void)testTemperatureConversionFahrenheit
{
    NSNumber *celsius = [NSNumber numberWithFloat:19.0];
    NSNumber *fahrenheit = [WeatherModel convertCelsiusToFahrenheit: celsius];
    XCTAssertEqual([fahrenheit floatValue], 66.2f, @"Fahrenheit conversion should equal 68, got %f", [fahrenheit floatValue]);
}

#pragma mark - Parsing

- (void)testDateCanBeConvertedToNaturalLanguage
{
    NSDate *testDate = [NSDate date];
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    [f setDateStyle:NSDateFormatterShortStyle];
    [f setTimeStyle:NSDateFormatterShortStyle];
    
    NSString *testString = [WeatherModel parseDate:testDate];
    XCTAssertEqualObjects(testString, [f stringFromDate:testDate], @"NSDate parsed incorrectly");
}

- (void)testJSONDatafileCanBeLoaded
{
    data = [WeatherModelExtensions loadJSONFromFile];
    XCTAssertNotNil(data, @"Example response should be loaded from file");
}

- (void)testNSDataCanBeParsedToDictionary
{
    data = [WeatherModelExtensions loadJSONFromFile];
    id testData = [WeatherModel parseJSONData:data];
    XCTAssertTrue([[testData class] isSubclassOfClass: [NSMutableDictionary class]], @"Data should be NSMutableDictionary format");
}

#pragma mark - Update properties
- (void)testWeatherDescriptionCanBeUpdatedFromParsedData
{
    [model updateWeatherDescriptionFromDictionary:parsedData];
    XCTAssertEqualObjects(model.weatherDescription, @"light rain", @"Weather description property should be set");
}

- (void)testTemperatureCanBeUpdatedFromParsedData
{
    [model updateTemperatureFromDictionary:parsedData];
    XCTAssertEqualObjects(model.temperature, @285.82999999999998, @"Temperature property should be set");
}

- (void)testIconStringCanBeUpdatedFromParsedData
{
    [model updateIconFromDictionary:parsedData];
    XCTAssertEqualObjects(model.icon, @"10n", @"Icon property should be set");
}

- (void)testLocationNameCanBeUpdatedFromParsedData
{
    [model updateLocationNameFromDictionary:parsedData];
    XCTAssertEqualObjects(model.locationName, @"East Ham", @"Location name property should be set");
}

- (void)testLastUpdatedDateCanBeUpdatedFromParsedData
{
    [model updateLastUpdatedDateFromDictionary:parsedData];
    XCTAssertEqualObjects(model.lastUpdated, [NSDate dateWithTimeIntervalSince1970:1382224998], @"Last updated date property should be set");
}

- (void)testLocationCanBeUpdatedFromParsedData
{
    // We only care about the location coordinates here
    double lat = 51.509999999999998;
    double lon = 0.13;
    CLLocationCoordinate2D coords = CLLocationCoordinate2DMake(lat, lon);
    
    [model updateLocationFromDictionary:parsedData];
    XCTAssertEqual(model.location.coordinate, coords, @"Location property should be set");
}

#pragma mark - Get values
- (void)testGetTemperatureInCelsius
{
    model.temperature = [NSNumber numberWithFloat:284.94];
    NSNumber *expected = [NSNumber numberWithFloat:11.79];
    XCTAssertEqualWithAccuracy([[model getTemperatureInCelsius] floatValue], [expected floatValue], 0.00001, @"Model should return temperature in celsius");
}
- (void)testGetTemperatureInFahrenheit
{
    model.temperature = [NSNumber numberWithFloat:284.94];
    NSNumber *expected = [NSNumber numberWithFloat:53.222];
    XCTAssertEqualWithAccuracy([[model getTemperatureInFahrenheit] floatValue], [expected floatValue], 0.00001, @"Model should return temperature in fahrenheit");
}

- (void)testModelReturnsDetailedWeatherDescriptionStringText
{
    model.temperature = [NSNumber numberWithFloat:284.94];
    model.weatherDescription = @"Cloudy";
    model.locationName = @"London";
    NSString *expectedAnswer = @"London 12º\nCloudy";
    XCTAssertEqualObjects([[model getDetailedWeatherDescriptionString] string], expectedAnswer, @"Model should return a detailed weather description string");
}

// This is an oversimplistic test. It doesn't set that that any of the
// attributes are being set
// TODO: Make test more robust
- (void)testModelReturnsDetailedWeatherDescriptionAsAttributedString
{
    model.temperature = [NSNumber numberWithFloat:284.94];
    model.weatherDescription = @"Cloudy";
    model.locationName = @"London";
    id description = [model getDetailedWeatherDescriptionString];
    XCTAssertTrue([[description class] isSubclassOfClass:[NSAttributedString class]], @"Description should be an attributed string");
}

#pragma mark - Delegate
- (void)testDelegateCallback
{
    model.delegate = self;
    [model.delegate weatherModelUpdated];
    XCTAssertTrue(callbackInvoked, @"Delegate callback should be called");
    model.delegate = nil;
}

- (void)weatherModelUpdated
{
    callbackInvoked = YES;
}

@end
