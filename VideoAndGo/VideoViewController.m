//
//  VideoViewController.m
//  VideoAndGo
//
//  Created by Michael Frain on 3/11/15.
//  Copyright (c) 2015 Michael Frain. All rights reserved.
//

#import "VideoViewController.h"

@interface VideoViewController ()

@property BOOL isRecording;

// AVCapture objects
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

// IBOutlets
@property (nonatomic, weak) IBOutlet UIImageView *imgVideoViewer;
@property (nonatomic, weak) IBOutlet UIButton *btnRecord;

// IBActions
- (IBAction)recordPressed:(id)sender;

@end

@implementation VideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.hidden = YES;
    // Video input
    self.session = [[AVCaptureSession alloc] init];
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (videoDevice) {
        NSError *error;
        self.videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        if (error) {
            NSLog(@"Error adding video input: %@", [error localizedDescription]);
        } else {
            if ([self.session canAddInput:self.videoInput]) {
                [self.session addInput:self.videoInput];
            } else {
                NSLog(@"Cannot add video input.");
            }
        }
    } else {
        NSLog(@"AVCaptureDevice for video is nil.");
    }
    
    // Audio input
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    if (audioDevice) {
        NSError *error;
        self.audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
        if (error) {
            NSLog(@"Error adding audio input: %@", [error localizedDescription]);
        } else {
            if ([self.session canAddInput:self.audioInput]) {
                [self.session addInput:self.audioInput];
            } else {
                NSLog(@"Cannot add audio input.");
            }
        }
    } else {
        NSLog(@"AVCaptureDevice for audio is nil.");
    }
    
    // Preview layer (used to view the video as it is being recorded)
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.imgVideoViewer.bounds;
    [self.imgVideoViewer.layer addSublayer:self.previewLayer];
    
    // Movie file output
    self.movieOutput = [[AVCaptureMovieFileOutput alloc] init];
    
    if ([self.session canAddOutput:self.movieOutput]) {
        [self.session addOutput:self.movieOutput];
    } else {
        NSLog(@"Cannot add movie output.");
    }
    
    [self.session startRunning];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)recordPressed:(id)sender {
    if (self.isRecording) {
        [self.movieOutput stopRecording];
        [self.btnRecord setTitle:@"🔴" forState:UIControlStateNormal];
    } else {
        NSString *outputString = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"output.mov"];
        NSURL *outputUrl = [NSURL fileURLWithPath:outputString];
        NSFileManager *manager = [NSFileManager defaultManager];
        if ([manager fileExistsAtPath:outputString]) {
            NSError *error;
            if (![manager removeItemAtPath:outputString error:&error]) {
                NSLog(@"Could not remove existing file: %@", [error localizedDescription]);
            }
        }
        [self.movieOutput startRecordingToOutputFileURL:outputUrl recordingDelegate:self];
        [self.btnRecord setTitle:@"◼️" forState:UIControlStateNormal];
    }
    self.isRecording = !self.isRecording;
}

#pragma mark - AVCaptureFileOutputRecordingDelegate Methods
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections {
    NSLog(@"Recording started at %@", fileURL);
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    NSLog(@"Recording finished at %@", outputFileURL);
    
    if (error) {
        NSLog(@"Recording unsuccessful: %@", [error localizedDescription]);
    } else {
        NSLog(@"Recording successful!");
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:outputFileURL options:nil];
        NSString *filename = [self createFilename];
        NSString *filepath = [NSString stringWithFormat:@"%@/%@", [self storageLocation], filename];
        AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
        
        session.outputURL = [NSURL fileURLWithPath:filepath];
        session.outputFileType = AVFileTypeMPEG4;
        session.shouldOptimizeForNetworkUse = YES;
        
        [session exportAsynchronouslyWithCompletionHandler:^{
            switch (session.status) {
                case AVAssetExportSessionStatusCancelled:
                    NSLog(@"Export cancelled by user.");
                    break;
                    
                case AVAssetExportSessionStatusCompleted:
                    NSLog(@"Export completed successfully.");
                    break;
                    
                case AVAssetExportSessionStatusExporting:
                    NSLog(@"Export still in progress.");
                    break;
                    
                case AVAssetExportSessionStatusFailed:
                    NSLog(@"Export failed: %@", [session.error localizedDescription]);
                    break;
                    
                case AVAssetExportSessionStatusUnknown:
                    NSLog(@"Export status unknown.");
                    break;
                    
                case AVAssetExportSessionStatusWaiting:
                    NSLog(@"Export still waiting.");
                    break;
            }
        }];
    }
}

#pragma mark - Helper functions

- (NSString *)createFilename {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MMMdd||HH:mm:SS"];
    NSDate *date = [NSDate date];
    NSString *dateString = [formatter stringFromDate:date];
    
    NSString *fileName = [NSString stringWithFormat:@"%@.mp4", dateString];
    
    return fileName;
}

- (NSString *)storageLocation {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"/capture"];
    
    NSError *error;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:dataPath withIntermediateDirectories:NO attributes:nil error:&error];
    
    return dataPath;
}

@end
