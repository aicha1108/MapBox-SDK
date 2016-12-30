//
//  ViewController.m
//  MapBoxiOS
//
//  Created by Hadassah on 12/13/16.
//  Copyright © 2016 Aiza Simbra. All rights reserved.
//

#import "ViewController.h"
@import Mapbox;

@interface ViewController ()<MGLMapViewDelegate>

@property(nonatomic, strong)MGLMapView *mapView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self loadMap];
    [self drawPolyline];
    [self drawPointConversion];
}

#pragma mark - Map
- (void)loadMap{
    
    NSURL *styleURL = [NSURL URLWithString:@"mapbox://styles/mapbox/streets-v9"];
    self.mapView = [[MGLMapView alloc] initWithFrame:self.view.bounds
                                    styleURL:styleURL];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.mapView setCenterCoordinate:CLLocationCoordinate2DMake(43.723, 10.396633) zoomLevel:7 animated:NO];
    
    self.mapView.delegate = self;
    [self.view addSubview:self.mapView];
    
    MGLPointAnnotation *marker = [[MGLPointAnnotation alloc] init];
    marker.coordinate = CLLocationCoordinate2DMake(43.723, 10.396633);
    
    marker.title = @"Leaning Tower of Pisa";
    marker.subtitle = @"Pisa";
    [self.mapView addAnnotation:marker];
    
    CGPoint centerScreenPoint = [self.mapView convertCoordinate:self.mapView.centerCoordinate
                                                  toPointToView:self.mapView];
    
    NSLog(@"Screen center: %@ = %@",
          NSStringFromCGPoint(centerScreenPoint),
          NSStringFromCGPoint(self.mapView.center));
    
}

- (void)drawPolyline{
    
    // Perform GeoJSON parsing on a background thread
    dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(backgroundQueue, ^(void)
   {
       // Get the path for example.geojson in the app's bundle
       NSString *jsonPath = [[NSBundle mainBundle] pathForResource:@"example" ofType:@"geojson"];
       
       // Load and serialize the GeoJSON into a dictionary filled with properly-typed objects
       NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:[[NSData alloc] initWithContentsOfFile:jsonPath] options:0 error:nil];
       
       // Load the `features` dictionary for iteration
       for (NSDictionary *feature in jsonDict[@"features"])
       {
           // Our GeoJSON only has one feature: a line string
           if ([feature[@"geometry"][@"type"] isEqualToString:@"LineString"])
           {
               // Get the raw array of coordinates for our line
               NSArray *rawCoordinates = feature[@"geometry"][@"coordinates"];
               NSUInteger coordinatesCount = rawCoordinates.count;
               
               // Create a coordinates array, sized to fit all of the coordinates in the line.
               // This array will hold the properly formatted coordinates for our MGLPolyline.
               CLLocationCoordinate2D coordinates[coordinatesCount];
               
               // Iterate over `rawCoordinates` once for each coordinate on the line
               for (NSUInteger index = 0; index < coordinatesCount; index++)
               {
                   // Get the individual coordinate for this index
                   NSArray *point = [rawCoordinates objectAtIndex:index];
                   
                   // GeoJSON is "longitude, latitude" order, but we need the opposite
                   CLLocationDegrees lat = [[point objectAtIndex:1] doubleValue];
                   CLLocationDegrees lng = [[point objectAtIndex:0] doubleValue];
                   CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat, lng);
                   
                   // Add this formatted coordinate to the final coordinates array at the same index
                   coordinates[index] = coordinate;
               }
               
               // Create our polyline with the formatted coordinates array
               MGLPolyline *polyline = [MGLPolyline polylineWithCoordinates:coordinates count:coordinatesCount];
               
               // Optionally set the title of the polyline, which can be used for:
               //  - Callout view
               //  - Object identification
               // In this case, set it to the name included in the GeoJSON
               polyline.title = feature[@"properties"][@"name"]; // "Crema to Council Crest"
               
               // Add the polyline to the map, back on the main thread
               // Use weak reference to self to prevent retain cycle
               __weak typeof(self) weakSelf = self;
               dispatch_async(dispatch_get_main_queue(), ^(void)
                              {
                                  [weakSelf.mapView addAnnotation:polyline];
                              });
           }
       }
       
   });
}

- (void)drawPointConversion{
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:nil];
    doubleTap.numberOfTapsRequired = 2;
    [self.mapView addGestureRecognizer:doubleTap];
    
    //add point conversion using singleTap
    /*UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.mapView addGestureRecognizer:singleTap];*/
}

#pragma mark - UITapGestureRecognizer
- (void)handleSingleTap:(UITapGestureRecognizer *)tapGestureRecognizer{
    //convert point location to coordinates
    CLLocationCoordinate2D location = [self.mapView convertPoint:[tapGestureRecognizer locationInView:self.mapView]
                                            toCoordinateFromView:self.mapView];
    
    NSLog(@"You tapped at: %.5f, %.5f", location.latitude, location.longitude);
    
    // create an array of coordinates for our polyline
    CLLocationCoordinate2D coordinates[] = {
        self.mapView.centerCoordinate,
        location
    };
    NSUInteger numberOfCoordinates = sizeof(coordinates) / sizeof(CLLocationCoordinate2D);
    
    // remove existing polyline from the map, (re)add polyline with coordinates
    if (self.mapView.annotations.count) {
        [self.mapView removeAnnotations:self.mapView.annotations];
    }
    MGLPolyline *polyline = [MGLPolyline polylineWithCoordinates:coordinates
                                                           count:numberOfCoordinates];
    [self.mapView addAnnotation:polyline];
}

#pragma mark - MGLMapViewDelegate
- (BOOL)mapView:(MGLMapView *)mapView annotationCanShowCallout:(id <MGLAnnotation>)annotation {
    return YES;
}

- (MGLAnnotationImage *)mapView:(MGLMapView *)mapView imageForAnnotation:(id <MGLAnnotation>)annotation{
    MGLAnnotationImage *annotationImage = [mapView dequeueReusableAnnotationImageWithIdentifier:@"pisa"];
    
    if (!annotationImage)
    {
        UIImage *image = [UIImage imageNamed:@"pisavector"];
        
        image = [image imageWithAlignmentRectInsets:UIEdgeInsetsMake(0, 0, image.size.height/2, 0)];
        
        annotationImage = [MGLAnnotationImage annotationImageWithImage:image reuseIdentifier:@"pisa"];
    }
    return annotationImage;
}

-(void)mapViewDidFinishLoadingMap:(MGLMapView *)mapView {
    // Wait for the map to load before initiating the first camera movement.
    
    // Create a camera that rotates around the same center point, rotating 180°.
    // `fromDistance:` is meters above mean sea level that an eye would have to be in order to see what the map view is showing.
    MGLMapCamera *camera = [MGLMapCamera cameraLookingAtCenterCoordinate:mapView.centerCoordinate fromDistance:4500 pitch:15 heading:180];
    
    // Animate the camera movement over 5 seconds.
    [mapView setCamera:camera withDuration:5 animationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
}

#pragma mark -
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
