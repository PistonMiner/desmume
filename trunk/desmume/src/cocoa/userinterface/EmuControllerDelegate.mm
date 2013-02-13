/*
	Copyright (C) 2013 DeSmuME team

	This file is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 2 of the License, or
	(at your option) any later version.

	This file is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with the this software.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "EmuControllerDelegate.h"
#import "emuWindowDelegate.h"
#import "displayView.h"
#import "cheatWindowDelegate.h"

#import "cocoa_globals.h"
#import "cocoa_cheat.h"
#import "cocoa_core.h"
#import "cocoa_file.h"
#import "cocoa_firmware.h"
#import "cocoa_GPU.h"
#import "cocoa_output.h"
#import "cocoa_rom.h"


@implementation EmuControllerDelegate

@synthesize currentRom;
@dynamic cdsFirmware;
@dynamic cdsSpeaker;
@synthesize cdsCheats;

@synthesize cheatWindowDelegate;
@synthesize firmwarePanelController;
@synthesize romInfoPanelController;
@synthesize cdsCoreController;
@synthesize cdsSoundController;
@synthesize cheatWindowController;
@synthesize cheatListController;
@synthesize cheatDatabaseController;

@synthesize saveFileMigrationSheet;
@synthesize saveStatePrecloseSheet;
@synthesize exportRomSavePanelAccessoryView;

@synthesize isWorking;
@synthesize isRomLoading;
@synthesize statusText;
@dynamic currentVolumeValue;
@synthesize currentVolumeIcon;

@synthesize isShowingSaveStateDialog;
@synthesize isShowingFileMigrationDialog;
@synthesize isUserInterfaceBlockingExecution;

@synthesize currentSaveStateURL;
@synthesize selectedRomSaveTypeID;

@dynamic render3DRenderingEngine;
@dynamic render3DHighPrecisionColorInterpolation;
@dynamic render3DEdgeMarking;
@dynamic render3DFog;
@dynamic render3DTextures;
@dynamic render3DDepthComparisonThreshold;
@dynamic render3DThreads;
@dynamic render3DLineHack;
@dynamic render3DMultisample;

@synthesize windowList;


-(id)init
{
	self = [super init];
	if(self == nil)
	{
		return nil;
	}
	
	windowList = [[NSMutableArray alloc] initWithCapacity:32];
	
	currentRom = nil;
	cdsFirmware = nil;
	cdsSpeaker = nil;
	dummyCheatList = nil;
	
	isSaveStateEdited = NO;
	isShowingSaveStateDialog = NO;
	isShowingFileMigrationDialog = NO;
	isUserInterfaceBlockingExecution = NO;
	
	currentSaveStateURL = nil;
	selectedExportRomSaveID = 0;
	selectedRomSaveTypeID = ROMSAVETYPE_AUTOMATIC;
	
	iconExecute = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Icon_Execute_420x420" ofType:@"png"]];
	iconPause = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Icon_Pause_420x420" ofType:@"png"]];
	iconSpeedNormal = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Icon_Speed1x_420x420" ofType:@"png"]];
	iconSpeedDouble = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Icon_Speed2x_420x420" ofType:@"png"]];
	iconVolumeFull = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Icon_VolumeFull_16x16" ofType:@"png"]];
	iconVolumeTwoThird = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Icon_VolumeTwoThird_16x16" ofType:@"png"]];
	iconVolumeOneThird = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Icon_VolumeOneThird_16x16" ofType:@"png"]];
	iconVolumeMute = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Icon_VolumeMute_16x16" ofType:@"png"]];
	
	isWorking = NO;
	isRomLoading = NO;
	statusText = NSSTRING_STATUS_READY;
	currentVolumeValue = MAX_VOLUME;
	currentVolumeIcon = [iconVolumeFull retain];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(loadRomDidFinish:)
												 name:@"org.desmume.DeSmuME.loadRomDidFinish"
											   object:nil];
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[iconExecute release];
	[iconPause release];
	[iconSpeedNormal release];
	[iconSpeedDouble release];
	[iconVolumeFull release];
	[iconVolumeTwoThird release];
	[iconVolumeOneThird release];
	[iconVolumeMute release];
	
	[[self currentRom] release];
	[self setCurrentRom:nil];
	
	[self setCdsCheats:nil];
	[self setCdsSpeaker:nil];
	
	[self setIsWorking:NO];
	[self setStatusText:@""];
	[self setCurrentVolumeValue:0.0f];
	[self setCurrentVolumeIcon:nil];
	
	[romInfoPanelController setContent:[CocoaDSRom romNotLoadedBindings]];
	
	[windowList release];
	
	[super dealloc];
}

- (void) setCdsFirmware:(CocoaDSFirmware *)theFirmware
{
	if (theFirmware == nil)
	{
		if (cdsFirmware != nil)
		{
			[cdsFirmware release];
			cdsFirmware = nil;
		}
	}
	else
	{
		cdsFirmware = [theFirmware retain];
	}
	
	[firmwarePanelController setContent:cdsFirmware];
}

- (CocoaDSFirmware *) cdsFirmware
{
	return cdsFirmware;
}

- (void) setCdsSpeaker:(CocoaDSSpeaker *)theSpeaker
{
	if (theSpeaker == nil)
	{
		if (cdsSpeaker != nil)
		{
			[cdsSpeaker release];
			cdsSpeaker = nil;
		}
	}
	else
	{
		cdsSpeaker = [theSpeaker retain];
	}
	
	[cdsSoundController setContent:[cdsSpeaker property]];
}

- (CocoaDSSpeaker *) cdsSpeaker
{
	return cdsSpeaker;
}

- (void) setCurrentVolumeValue:(float)vol
{
	currentVolumeValue = vol;
	
	// Update the icon.
	NSImage *currentImage = [self currentVolumeIcon];
	NSImage *newImage = nil;
	if (vol <= 0.0f)
	{
		newImage = iconVolumeMute;
	}
	else if (vol > 0.0f && vol <= VOLUME_THRESHOLD_LOW)
	{
		newImage = iconVolumeOneThird;
	}
	else if (vol > VOLUME_THRESHOLD_LOW && vol <= VOLUME_THRESHOLD_HIGH)
	{
		newImage = iconVolumeTwoThird;
	}
	else
	{
		newImage = iconVolumeFull;
	}
	
	if (newImage != currentImage)
	{
		[self setCurrentVolumeIcon:newImage];
	}
}

- (float) currentVolumeValue
{
	return currentVolumeValue;
}

- (IBAction) openRom:(id)sender
{
	if ([self isRomLoading])
	{
		return;
	}
	
	NSURL *selectedFile = nil;
	NSInteger buttonClicked = NSFileHandlingPanelCancelButton;
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	[panel setResolvesAliases:YES];
	[panel setAllowsMultipleSelection:NO];
	[panel setTitle:NSSTRING_TITLE_OPEN_ROM_PANEL];
	NSArray *fileTypes = [NSArray arrayWithObjects:@FILE_EXT_ROM_DS, @FILE_EXT_ROM_GBA, nil]; 
	
	// The NSOpenPanel method -(NSInt)runModalForDirectory:file:types:
	// is deprecated in Mac OS X v10.6.
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
	[panel setAllowedFileTypes:fileTypes];
	buttonClicked = [panel runModal];
#else
	buttonClicked = [panel runModalForDirectory:nil file:nil types:fileTypes];
#endif
	
	if (buttonClicked == NSFileHandlingPanelOKButton)
	{
		selectedFile = [[panel URLs] lastObject];
		if(selectedFile == nil)
		{
			return;
		}
	}
	else
	{
		return;
	}
	
	[self handleLoadRom:selectedFile];
}

- (IBAction) closeRom:(id)sender
{
	[self handleUnloadRom:REASONFORCLOSE_NORMAL romToLoad:nil];
}

- (IBAction) openEmuSaveState:(id)sender
{
	BOOL result = NO;
	NSURL *selectedFile = nil;
	NSInteger buttonClicked = NSFileHandlingPanelCancelButton;
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	[panel setResolvesAliases:YES];
	[panel setAllowsMultipleSelection:NO];
	[panel setTitle:NSSTRING_TITLE_OPEN_STATE_FILE_PANEL];
	NSArray *fileTypes = [NSArray arrayWithObjects:@FILE_EXT_SAVE_STATE, nil];
	
	// The NSOpenPanel method -(NSInt)runModalForDirectory:file:types:
	// is deprecated in Mac OS X v10.6.
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
	[panel setAllowedFileTypes:fileTypes];
	buttonClicked = [panel runModal];
#else
	buttonClicked = [panel runModalForDirectory:nil file:nil types:fileTypes];
#endif
	
	if (buttonClicked == NSFileHandlingPanelOKButton)
	{
		selectedFile = [[panel URLs] lastObject];
		if(selectedFile == nil)
		{
			return;
		}
	}
	else
	{
		return;
	}
	
	[self pauseCore];
	
	result = [CocoaDSFile loadState:selectedFile];
	if (result == NO)
	{
		[self setStatusText:NSSTRING_STATUS_SAVESTATE_LOADING_FAILED];
		[self restoreCoreState];
		return;
	}
	
	[self setCurrentSaveStateURL:selectedFile];
	[self restoreCoreState];
	[self setStatusText:NSSTRING_STATUS_SAVESTATE_LOADED];
	
	isSaveStateEdited = YES;
	for (NSWindow *theWindow in windowList)
	{
		[theWindow setDocumentEdited:isSaveStateEdited];
	}
}

- (IBAction) saveEmuSaveState:(id)sender
{
	BOOL result = NO;
	
	if (isSaveStateEdited && [self currentSaveStateURL] != nil)
	{
		[self pauseCore];
		
		result = [CocoaDSFile saveState:[self currentSaveStateURL]];
		if (result == NO)
		{
			[self setStatusText:NSSTRING_STATUS_SAVESTATE_SAVING_FAILED];
			return;
		}
		
		isSaveStateEdited = YES;
		for (NSWindow *theWindow in windowList)
		{
			[theWindow setDocumentEdited:isSaveStateEdited];
		}
		
		[self restoreCoreState];
		[self setStatusText:NSSTRING_STATUS_SAVESTATE_SAVED];
	}
	else
	{
		[self saveEmuSaveStateAs:sender];
	}
}

- (IBAction) saveEmuSaveStateAs:(id)sender
{
	BOOL result = NO;
	NSInteger buttonClicked = NSFileHandlingPanelCancelButton;
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setCanCreateDirectories:YES];
	[panel setTitle:NSSTRING_TITLE_SAVE_STATE_FILE_PANEL];
	
	// The NSSavePanel method -(void)setRequiredFileType:
	// is deprecated in Mac OS X v10.6.
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
	NSArray *fileTypes = [NSArray arrayWithObjects:@FILE_EXT_SAVE_STATE, nil];
	[panel setAllowedFileTypes:fileTypes];
#else
	[panel setRequiredFileType:@FILE_EXT_SAVE_STATE];
#endif
	
	buttonClicked = [panel runModal];
	if(buttonClicked == NSOKButton)
	{
		[self pauseCore];
		
		NSURL *saveFileURL = [panel URL];
		
		result = [CocoaDSFile saveState:saveFileURL];
		if (result == NO)
		{
			[self setStatusText:NSSTRING_STATUS_SAVESTATE_SAVING_FAILED];
			return;
		}
		
		[self setCurrentSaveStateURL:saveFileURL];
		[self restoreCoreState];
		[self setStatusText:NSSTRING_STATUS_SAVESTATE_SAVED];
		
		isSaveStateEdited = YES;
		for (NSWindow *theWindow in windowList)
		{
			[theWindow setDocumentEdited:isSaveStateEdited];
		}
	}
}

- (IBAction) revertEmuSaveState:(id)sender
{
	BOOL result = NO;
	
	if (isSaveStateEdited && [self currentSaveStateURL] != nil)
	{
		[self pauseCore];
		
		result = [CocoaDSFile loadState:[self currentSaveStateURL]];
		if (result == NO)
		{
			[self setStatusText:NSSTRING_STATUS_SAVESTATE_REVERTING_FAILED];
			return;
		}
		
		isSaveStateEdited = YES;
		for (NSWindow *theWindow in windowList)
		{
			[theWindow setDocumentEdited:isSaveStateEdited];
		}
		
		[self restoreCoreState];
		[self setStatusText:NSSTRING_STATUS_SAVESTATE_REVERTED];
	}
}

- (IBAction) loadEmuSaveStateSlot:(id)sender
{
	BOOL result = NO;
	NSInteger i = [CocoaDSUtil getIBActionSenderTag:sender];
	
	NSString *saveStatePath = [[CocoaDSFile saveStateURL] path];
	if (saveStatePath == nil)
	{
		// Should throw an error message here...
		return;
	}
	
	if (i < 0 || i > MAX_SAVESTATE_SLOTS)
	{
		return;
	}
	
	NSURL *currentRomURL = [[self currentRom] fileURL];
	NSString *fileName = [CocoaDSFile saveSlotFileName:currentRomURL slotNumber:(NSUInteger)(i + 1)];
	if (fileName == nil)
	{
		return;
	}
	
	[self pauseCore];
	
	result = [CocoaDSFile loadState:[NSURL fileURLWithPath:[saveStatePath stringByAppendingPathComponent:fileName]]];
	if (result == NO)
	{
		[self setStatusText:NSSTRING_STATUS_SAVESTATE_LOADING_FAILED];
	}
	
	[self restoreCoreState];
	[self setStatusText:NSSTRING_STATUS_SAVESTATE_LOADED];
}

- (IBAction) saveEmuSaveStateSlot:(id)sender
{
	BOOL result = NO;
	NSInteger i = [CocoaDSUtil getIBActionSenderTag:sender];
	
	NSString *saveStatePath = [[CocoaDSFile saveStateURL] path];
	if (saveStatePath == nil)
	{
		[self setStatusText:NSSTRING_STATUS_CANNOT_GENERATE_SAVE_PATH];
		return;
	}
	
	result = [CocoaDSFile createUserAppSupportDirectory:@"States"];
	if (result == NO)
	{
		[self setStatusText:NSSTRING_STATUS_CANNOT_CREATE_SAVE_DIRECTORY];
		return;
	}
	
	if (i < 0 || i > MAX_SAVESTATE_SLOTS)
	{
		return;
	}
	
	NSURL *currentRomURL = [[self currentRom] fileURL];
	NSString *fileName = [CocoaDSFile saveSlotFileName:currentRomURL slotNumber:(NSUInteger)(i + 1)];
	if (fileName == nil)
	{
		return;
	}
	
	[self pauseCore];
	
	result = [CocoaDSFile saveState:[NSURL fileURLWithPath:[saveStatePath stringByAppendingPathComponent:fileName]]];
	if (result == NO)
	{
		[self setStatusText:NSSTRING_STATUS_SAVESTATE_SAVING_FAILED];
		return;
	}
	
	[self restoreCoreState];
	[self setStatusText:NSSTRING_STATUS_SAVESTATE_SAVED];
}

- (IBAction) importRomSave:(id)sender
{
	NSURL *selectedFile = nil;
	NSInteger buttonClicked = NSFileHandlingPanelCancelButton;
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	[panel setResolvesAliases:YES];
	[panel setAllowsMultipleSelection:NO];
	[panel setTitle:NSSTRING_TITLE_IMPORT_ROM_SAVE_PANEL];
	NSArray *fileTypes = [NSArray arrayWithObjects:@FILE_EXT_ROM_SAVE_RAW, @FILE_EXT_ACTION_REPLAY_SAVE, nil];
	
	// The NSOpenPanel method -(NSInt)runModalForDirectory:file:types:
	// is deprecated in Mac OS X v10.6.
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
	[panel setAllowedFileTypes:fileTypes];
	buttonClicked = [panel runModal];
#else
	buttonClicked = [panel runModalForDirectory:nil file:nil types:fileTypes];
#endif
	
	if (buttonClicked == NSFileHandlingPanelOKButton)
	{
		selectedFile = [[panel URLs] lastObject];
		if(selectedFile == nil)
		{
			return;
		}
	}
	else
	{
		return;
	}
	
	BOOL result = [CocoaDSFile importRomSave:selectedFile];
	if (!result)
	{
		[self setStatusText:NSSTRING_STATUS_ROM_SAVE_IMPORT_FAILED];
		return;
	}
	
	[self setStatusText:NSSTRING_STATUS_ROM_SAVE_IMPORTED];
}

- (IBAction) exportRomSave:(id)sender
{
	[self pauseCore];
	
	BOOL result = NO;
	NSInteger buttonClicked;
	NSSavePanel *panel = [NSSavePanel savePanel];
	[panel setTitle:NSSTRING_TITLE_EXPORT_ROM_SAVE_PANEL];
	[panel setCanCreateDirectories:YES];
	[panel setAccessoryView:exportRomSavePanelAccessoryView];
	
	buttonClicked = [panel runModal];
	if(buttonClicked == NSOKButton)
	{
		NSURL *romSaveURL = [CocoaDSFile fileURLFromRomURL:[[self currentRom] fileURL] toKind:@"ROM Save"];
		if (romSaveURL != nil)
		{
			result = [CocoaDSFile exportRomSaveToURL:[panel URL] romSaveURL:romSaveURL fileType:selectedExportRomSaveID];
			if (result == NO)
			{
				[self setStatusText:NSSTRING_STATUS_ROM_SAVE_EXPORT_FAILED];
				return;
			}
			
			[self setStatusText:NSSTRING_STATUS_ROM_SAVE_EXPORTED];
		}
	}
	
	[self restoreCoreState];
}

- (IBAction) selectExportRomSaveFormat:(id)sender
{
	selectedExportRomSaveID = [CocoaDSUtil getIBActionSenderTag:sender];
}

- (IBAction) executeCoreToggle:(id)sender
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	
	if ([cdsCore coreState] == CORESTATE_PAUSE)
	{
		if ([self currentRom] != nil)
		{
			[self executeCore];
		}
	}
	else
	{
		[self pauseCore];
	}
}

- (IBAction) resetCore:(id)sender
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	
	if ([self currentRom] != nil)
	{
		[self setStatusText:NSSTRING_STATUS_EMULATOR_RESETTING];
		[self setIsWorking:YES];
		
		for (NSWindow *theWindow in windowList)
		{
			[theWindow displayIfNeeded];
		}
		
		[cdsCore reset];
		if ([cdsCore coreState] == CORESTATE_PAUSE)
		{
			for (NSWindow *theWindow in windowList)
			{
				[[(EmuWindowDelegate *)[theWindow delegate] dispViewDelegate] setViewToWhite];
			}
		}
		
		[self setStatusText:NSSTRING_STATUS_EMULATOR_RESET];
		[self setIsWorking:NO];
		
		for (NSWindow *theWindow in windowList)
		{
			[theWindow displayIfNeeded];
		}
	}
}

- (IBAction) speedLimitDisable:(id)sender
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	
	if ([cdsCore isSpeedLimitEnabled])
	{
		[cdsCore setIsSpeedLimitEnabled:NO];
		[self setStatusText:NSSTRING_STATUS_SPEED_LIMIT_DISABLED];
	}
	else
	{
		[cdsCore setIsSpeedLimitEnabled:YES];
		[self setStatusText:NSSTRING_STATUS_SPEED_LIMIT_ENABLED];
	}
}

- (IBAction) toggleAutoFrameSkip:(id)sender
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	
	if ([cdsCore isFrameSkipEnabled])
	{
		[cdsCore setIsFrameSkipEnabled:NO];
		[self setStatusText:NSSTRING_STATUS_AUTO_FRAME_SKIP_DISABLED];
	}
	else
	{
		[cdsCore setIsFrameSkipEnabled:YES];
		[self setStatusText:NSSTRING_STATUS_AUTO_FRAME_SKIP_ENABLED];
	}
}

- (IBAction) changeRomSaveType:(id)sender
{
	const NSInteger saveTypeID = [CocoaDSUtil getIBActionSenderTag:sender];
	[self setSelectedRomSaveTypeID:saveTypeID];
	
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore changeRomSaveType:saveTypeID];
}

- (IBAction) cheatsDisable:(id)sender
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	
	if ([cdsCore isCheatingEnabled])
	{
		[cdsCore setIsCheatingEnabled:NO];
		[self setStatusText:NSSTRING_STATUS_CHEATS_DISABLED];
	}
	else
	{
		[cdsCore setIsCheatingEnabled:YES];
		[self setStatusText:NSSTRING_STATUS_CHEATS_ENABLED];
	}
}

- (IBAction) changeCoreSpeed:(id)sender
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	
	[cdsCore setSpeedScalar:(CGFloat)[CocoaDSUtil getIBActionSenderTag:sender] / 100.0f];
}

- (IBAction) changeCoreEmuFlags:(id)sender
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	NSUInteger flags = [cdsCore emulationFlags];
	
	NSInteger flagBit = [CocoaDSUtil getIBActionSenderTag:sender];
	if (flagBit < 0)
	{
		return;
	}
	
	BOOL flagState = [CocoaDSUtil getIBActionSenderButtonStateBool:sender];
	if (flagState)
	{
		flags |= (1 << flagBit);
	}
	else
	{
		flags &= ~(1 << flagBit);
	}
	
	[cdsCore setEmulationFlags:flags];
}

- (IBAction) changeFirmwareSettings:(id)sender
{
	// Force end of editing of any text fields.
	[[(NSControl *)sender window] makeFirstResponder:nil];
	
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[[cdsCore cdsFirmware] update];
}

- (IBAction) changeVolume:(id)sender
{
	float vol = [self currentVolumeValue];
	[self setCurrentVolumeValue:vol];
	[self setStatusText:[NSString stringWithFormat:NSSTRING_STATUS_VOLUME, vol]];
	[CocoaDSUtil messageSendOneWayWithFloat:[cdsSpeaker receivePort] msgID:MESSAGE_SET_VOLUME floatValue:vol];
}

- (IBAction) changeAudioEngine:(id)sender
{
	[CocoaDSUtil messageSendOneWayWithInteger:[cdsSpeaker receivePort] msgID:MESSAGE_SET_AUDIO_PROCESS_METHOD integerValue:[CocoaDSUtil getIBActionSenderTag:sender]];
}

- (IBAction) changeSpuAdvancedLogic:(id)sender
{
	[CocoaDSUtil messageSendOneWayWithBool:[cdsSpeaker receivePort] msgID:MESSAGE_SET_SPU_ADVANCED_LOGIC boolValue:[CocoaDSUtil getIBActionSenderButtonStateBool:sender]];
}

- (IBAction) changeSpuInterpolationMode:(id)sender
{
	[CocoaDSUtil messageSendOneWayWithInteger:[cdsSpeaker receivePort] msgID:MESSAGE_SET_SPU_INTERPOLATION_MODE integerValue:[CocoaDSUtil getIBActionSenderTag:sender]];
}

- (IBAction) changeSpuSyncMode:(id)sender
{
	[CocoaDSUtil messageSendOneWayWithInteger:[cdsSpeaker receivePort] msgID:MESSAGE_SET_SPU_SYNC_MODE integerValue:[CocoaDSUtil getIBActionSenderTag:sender]];
}

- (IBAction) changeSpuSyncMethod:(id)sender
{
	[CocoaDSUtil messageSendOneWayWithInteger:[cdsSpeaker receivePort] msgID:MESSAGE_SET_SPU_SYNC_METHOD integerValue:[CocoaDSUtil getIBActionSenderTag:sender]];
}

- (void) setRender3DRenderingEngine:(NSInteger)engineID
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore.cdsGPU setRender3DRenderingEngine:engineID];
}

- (NSInteger) render3DRenderingEngine
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	return [cdsCore.cdsGPU render3DRenderingEngine];
}

- (void) setRender3DHighPrecisionColorInterpolation:(BOOL)theState
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore.cdsGPU setRender3DHighPrecisionColorInterpolation:theState];
}

- (BOOL) render3DHighPrecisionColorInterpolation
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	return [cdsCore.cdsGPU render3DHighPrecisionColorInterpolation];
}

- (void) setRender3DEdgeMarking:(BOOL)theState
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore.cdsGPU setRender3DEdgeMarking:theState];
}

- (BOOL) render3DEdgeMarking
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	return [cdsCore.cdsGPU render3DEdgeMarking];
}

- (void) setRender3DFog:(BOOL)theState
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore.cdsGPU setRender3DFog:theState];
}

- (BOOL) render3DFog
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	return [cdsCore.cdsGPU render3DFog];
}

- (void) setRender3DTextures:(BOOL)theState
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore.cdsGPU setRender3DTextures:theState];
}

- (BOOL) render3DTextures
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	return [cdsCore.cdsGPU render3DTextures];
}

- (void) setRender3DDepthComparisonThreshold:(NSInteger)threshold
{
	if (threshold < 0)
	{
		return;
	}
	
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore.cdsGPU setRender3DDepthComparisonThreshold:(NSUInteger)threshold];
}

- (NSInteger) render3DDepthComparisonThreshold
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	return [cdsCore.cdsGPU render3DDepthComparisonThreshold];
}

- (void) setRender3DThreads:(NSInteger)threadCount
{
	if (threadCount < 0)
	{
		return;
	}
	
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore.cdsGPU setRender3DThreads:(NSUInteger)threadCount];
}

- (NSInteger) render3DThreads
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	return [cdsCore.cdsGPU render3DThreads];
}

- (void) setRender3DLineHack:(BOOL)theState
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore.cdsGPU setRender3DLineHack:theState];
}

- (BOOL) render3DLineHack
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	return [cdsCore.cdsGPU render3DLineHack];
}

- (void) setRender3DMultisample:(BOOL)theState
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore.cdsGPU setRender3DMultisample:theState];
}

- (BOOL) render3DMultisample
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	return [cdsCore.cdsGPU render3DMultisample];
}

- (IBAction) toggleGPUState:(id)sender
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	const NSInteger bitNumber = [CocoaDSUtil getIBActionSenderTag:sender];
	const UInt32 flagBit = [cdsCore.cdsGPU gpuStateFlags] ^ (1 << bitNumber);
	
	[cdsCore.cdsGPU setGpuStateFlags:flagBit];
}

- (IBAction) newDisplayWindow:(id)sender
{
	
}

- (BOOL) handleLoadRom:(NSURL *)fileURL
{
	BOOL result = NO;
	
	if ([self isRomLoading])
	{
		return result;
	}
	
	if ([self currentRom] != nil)
	{
		BOOL closeResult = [self handleUnloadRom:REASONFORCLOSE_OPEN romToLoad:fileURL];
		if ([self isShowingSaveStateDialog])
		{
			return result;
		}
		
		if (![self isShowingFileMigrationDialog] && closeResult == NO)
		{
			return result;
		}
	}
	
	// Check for the v0.9.7 ROM Save File
	if ([CocoaDSFile romSaveExistsWithRom:fileURL] && ![CocoaDSFile romSaveExists:fileURL])
	{
		[fileURL retain];
		[self setIsUserInterfaceBlockingExecution:YES];
		[self setIsShowingFileMigrationDialog:YES];
		
		[NSApp beginSheet:saveFileMigrationSheet
		   modalForWindow:(NSWindow *)[windowList objectAtIndex:0]
            modalDelegate:self
		   didEndSelector:@selector(didEndFileMigrationSheet:returnCode:contextInfo:)
			  contextInfo:fileURL];
	}
	else
	{
		result = [self loadRom:fileURL];
	}
	
	return result;
}

- (BOOL) handleUnloadRom:(NSInteger)reasonID romToLoad:(NSURL *)romURL
{
	BOOL result = NO;
	
	if ([self isRomLoading] || [self currentRom] == nil)
	{
		return result;
	}
	
	[self pauseCore];
	
	if (isSaveStateEdited && [self currentSaveStateURL] != nil)
	{
		SEL endSheetSelector = @selector(didEndSaveStateSheet:returnCode:contextInfo:);
		
		switch (reasonID)
		{
			case REASONFORCLOSE_OPEN:
				[romURL retain];
				endSheetSelector = @selector(didEndSaveStateSheetOpen:returnCode:contextInfo:);
				break;	
				
			case REASONFORCLOSE_TERMINATE:
				endSheetSelector = @selector(didEndSaveStateSheetTerminate:returnCode:contextInfo:);
				break;
				
			default:
				break;
		}
		
		[currentSaveStateURL retain];
		[self setIsUserInterfaceBlockingExecution:YES];
		[self setIsShowingSaveStateDialog:YES];
		
		[NSApp beginSheet:saveStatePrecloseSheet
		   modalForWindow:(NSWindow *)[windowList objectAtIndex:0]
            modalDelegate:self
		   didEndSelector:endSheetSelector
			  contextInfo:romURL];
	}
	else
	{
		result = [self unloadRom];
	}
	
	return result;
}

- (BOOL) loadRom:(NSURL *)romURL
{
	BOOL result = NO;
	
	if (romURL == nil)
	{
		return result;
	}
	
	[self setStatusText:NSSTRING_STATUS_ROM_LOADING];
	[self setIsWorking:YES];
	
	for (NSWindow *theWindow in windowList)
	{
		[theWindow displayIfNeeded];
	}
	
	// Need to pause the core before loading the ROM.
	[self pauseCore];
	
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore setDynaRec];
	
	CocoaDSRom *newRom = [[CocoaDSRom alloc] init];
	if (newRom != nil)
	{
		[self setIsRomLoading:YES];
		[romURL retain];
		[newRom setSaveType:selectedRomSaveTypeID];
		[NSThread detachNewThreadSelector:@selector(loadDataOnThread:) toTarget:newRom withObject:romURL];
		[romURL release];
	}
	
	result = YES;
	
	return result;
}

- (void) loadRomDidFinish:(NSNotification *)aNotification
{
	CocoaDSRom *theRom = [aNotification object];
	NSDictionary *userInfo = [aNotification userInfo];
	BOOL didLoad = [(NSNumber *)[userInfo valueForKey:@"DidLoad"] boolValue];
	
	if (theRom == nil || ![theRom isDataLoaded] || !didLoad)
	{
		// If ROM loading fails, restore the core state, but only if a ROM is already loaded.
		if([self currentRom] != nil)
		{
			[self restoreCoreState];
		}
		
		[self setStatusText:NSSTRING_STATUS_ROM_LOADING_FAILED];
		[self setIsWorking:NO];
		[self setIsRomLoading:NO];
		
		return;
	}
	
	// Set the core's ROM to our newly allocated ROM object.
	[self setCurrentRom:theRom];
	[romInfoPanelController setContent:[theRom bindings]];
	
	// If the ROM has an associated cheat file, load it now.
	NSString *cheatsPath = [[CocoaDSFile fileURLFromRomURL:[theRom fileURL] toKind:@"Cheat"] path];
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	CocoaDSCheatManager *newCheatList = [[[CocoaDSCheatManager alloc] initWithCore:cdsCore fileURL:[NSURL fileURLWithPath:cheatsPath]] autorelease];
	if (newCheatList != nil)
	{
		NSMutableDictionary *cheatWindowBindings = (NSMutableDictionary *)[cheatWindowController content];
		
		[CocoaDSCheatManager setMasterCheatList:newCheatList];
		[cheatListController setContent:[newCheatList list]];
		[self setCdsCheats:newCheatList];
		[cheatWindowBindings setValue:newCheatList forKey:@"cheatList"];
		
		NSString *filePath = [[NSUserDefaults standardUserDefaults] stringForKey:@"R4Cheat_DatabasePath"];
		if (filePath != nil)
		{
			NSURL *fileURL = [NSURL fileURLWithPath:filePath];
			NSInteger error = 0;
			NSMutableArray *dbList = [[self cdsCheats] cheatListFromDatabase:fileURL errorCode:&error];
			if (dbList != nil)
			{
				[cheatDatabaseController setContent:dbList];
				
				NSString *titleString = [[self cdsCheats] dbTitle];
				NSString *dateString = [[self cdsCheats] dbDate];
				
				[cheatWindowBindings setValue:titleString forKey:@"cheatDBTitle"];
				[cheatWindowBindings setValue:dateString forKey:@"cheatDBDate"];
				[cheatWindowBindings setValue:[NSString stringWithFormat:@"%ld", (unsigned long)[dbList count]] forKey:@"cheatDBItemCount"];
			}
			else
			{
				[cheatWindowBindings setValue:@"---" forKey:@"cheatDBItemCount"];
				
				switch (error)
				{
					case CHEATEXPORT_ERROR_FILE_NOT_FOUND:
						NSLog(@"R4 Cheat Database read failed! Could not load the database file!");
						[cheatWindowBindings setValue:@"Database not loaded." forKey:@"cheatDBTitle"];
						[cheatWindowBindings setValue:@"CANNOT LOAD FILE" forKey:@"cheatDBDate"];
						break;
						
					case CHEATEXPORT_ERROR_WRONG_FILE_FORMAT:
						NSLog(@"R4 Cheat Database read failed! Wrong file format!");
						[cheatWindowBindings setValue:@"Database load error." forKey:@"cheatDBTitle"];
						[cheatWindowBindings setValue:@"FAILED TO LOAD FILE" forKey:@"cheatDBDate"];
						break;
						
					case CHEATEXPORT_ERROR_SERIAL_NOT_FOUND:
						NSLog(@"R4 Cheat Database read failed! Could not find the serial number for this game in the database!");
						[cheatWindowBindings setValue:@"ROM not found in database." forKey:@"cheatDBTitle"];
						[cheatWindowBindings setValue:@"ROM not found." forKey:@"cheatDBDate"];
						break;
						
					case CHEATEXPORT_ERROR_EXPORT_FAILED:
						NSLog(@"R4 Cheat Database read failed! Could not read the database file!");
						[cheatWindowBindings setValue:@"Database read error." forKey:@"cheatDBTitle"];
						[cheatWindowBindings setValue:@"CANNOT READ FILE" forKey:@"cheatDBDate"];
						break;
						
					default:
						break;
				}
			}
		}
		
		[cheatWindowDelegate setCdsCheats:newCheatList];
		[[cheatWindowDelegate cdsCheatSearch] setCdsCore:cdsCore];
		[cheatWindowDelegate setCheatSearchViewByStyle:CHEATSEARCH_SEARCHSTYLE_EXACT_VALUE];
	}
	
	// Add the last loaded ROM to the Recent ROMs list.
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[theRom fileURL]];
	
	// Update the UI to indicate that a ROM has indeed been loaded.
	for (NSWindow *theWindow in windowList)
	{
		[theWindow setRepresentedURL:[theRom fileURL]];
		[[theWindow standardWindowButton:NSWindowDocumentIconButton] setImage:[theRom icon]];
		
		NSString *newWindowTitle = [theRom internalName];
		[theWindow setTitle:newWindowTitle];
		[[(EmuWindowDelegate *)[theWindow delegate] dispViewDelegate] setViewToWhite];
	}
	
	[self setStatusText:NSSTRING_STATUS_ROM_LOADED];
	[self setIsWorking:NO];
	[self setIsRomLoading:NO];
	
	for (NSWindow *theWindow in windowList)
	{
		[theWindow displayIfNeeded];
	}
	
	// After the ROM loading is complete, send an execute message to the Cocoa DS per
	// user preferences.
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"General_ExecuteROMOnLoad"])
	{
		[self executeCore];
	}
}

- (BOOL) unloadRom
{
	BOOL result = NO;
	
	[currentSaveStateURL release];
	currentSaveStateURL = nil;
	
	isSaveStateEdited = NO;
	for (NSWindow *theWindow in windowList)
	{
		[theWindow setDocumentEdited:isSaveStateEdited];
	}
	
	// Save the ROM's cheat list before unloading.
	[[self cdsCheats] save];
	
	// Update the UI to indicate that the ROM has started the process of unloading.
	[self setStatusText:NSSTRING_STATUS_ROM_UNLOADING];
	[romInfoPanelController setContent:[CocoaDSRom romNotLoadedBindings]];
	[cheatListController setContent:nil];
	[cheatWindowDelegate resetSearch:nil];
	[cheatWindowDelegate setCdsCheats:nil];
	[cheatDatabaseController setContent:nil];
	
	NSMutableDictionary *cheatWindowBindings = (NSMutableDictionary *)[cheatWindowController content];
	[cheatWindowBindings setValue:@"No ROM loaded." forKey:@"cheatDBTitle"];
	[cheatWindowBindings setValue:@"No ROM loaded." forKey:@"cheatDBDate"];
	[cheatWindowBindings setValue:@"---" forKey:@"cheatDBItemCount"];
	[cheatWindowBindings setValue:nil forKey:@"cheatList"];
	
	[self setIsWorking:YES];
	
	for (NSWindow *theWindow in windowList)
	{
		[theWindow displayIfNeeded];
	}
	
	// Unload the ROM.
	[[self currentRom] release];
	[self setCurrentRom:nil];
	
	// Release the current cheat list and assign the empty list.
	[self setCdsCheats:nil];
	if (dummyCheatList == nil)
	{
		dummyCheatList = [[CocoaDSCheatManager alloc] init];
	}
	[CocoaDSCheatManager setMasterCheatList:dummyCheatList];
	
	// Update the UI to indicate that the ROM has finished unloading.
	for (NSWindow *theWindow in windowList)
	{
		[theWindow setRepresentedURL:nil];
		NSString *newWindowTitle = (NSString *)[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
		[theWindow setTitle:newWindowTitle];
		[[(EmuWindowDelegate *)[theWindow delegate] dispViewDelegate] setViewToBlack];
	}
	
	[self setStatusText:NSSTRING_STATUS_ROM_UNLOADED];
	[self setIsWorking:NO];
	
	for (NSWindow *theWindow in windowList)
	{
		[theWindow displayIfNeeded];
	}
	
	result = YES;
	
	return result;
}

- (void) executeCore
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore setCoreState:CORESTATE_EXECUTE];
}

- (void) pauseCore
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore setCoreState:CORESTATE_PAUSE];
}

- (void) restoreCoreState
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	[cdsCore restoreCoreState];
}

- (void) setupUserDefaults
{
	// Set the SPU settings per user preferences.
	[self setCurrentVolumeValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"Sound_Volume"]];
	[[self cdsSpeaker] setVolume:[[NSUserDefaults standardUserDefaults] floatForKey:@"Sound_Volume"]];
	[[self cdsSpeaker] setAudioOutputEngine:[[NSUserDefaults standardUserDefaults] integerForKey:@"Sound_AudioOutputEngine"]];
	[[self cdsSpeaker] setSpuAdvancedLogic:[[NSUserDefaults standardUserDefaults] boolForKey:@"SPU_AdvancedLogic"]];
	[[self cdsSpeaker] setSpuInterpolationMode:[[NSUserDefaults standardUserDefaults] integerForKey:@"SPU_InterpolationMode"]];
	[[self cdsSpeaker] setSpuSyncMode:[[NSUserDefaults standardUserDefaults] integerForKey:@"SPU_SyncMode"]];
	[[self cdsSpeaker] setSpuSyncMethod:[[NSUserDefaults standardUserDefaults] integerForKey:@"SPU_SyncMethod"]];
	
	// Set the 3D rendering options per user preferences.
	[self setRender3DThreads:(NSUInteger)[[NSUserDefaults standardUserDefaults] integerForKey:@"Render3D_Threads"]];
	[self setRender3DRenderingEngine:[[NSUserDefaults standardUserDefaults] integerForKey:@"Render3D_RenderingEngine"]];
	[self setRender3DHighPrecisionColorInterpolation:[[NSUserDefaults standardUserDefaults] boolForKey:@"Render3D_HighPrecisionColorInterpolation"]];
	[self setRender3DEdgeMarking:[[NSUserDefaults standardUserDefaults] boolForKey:@"Render3D_EdgeMarking"]];
	[self setRender3DFog:[[NSUserDefaults standardUserDefaults] boolForKey:@"Render3D_Fog"]];
	[self setRender3DTextures:[[NSUserDefaults standardUserDefaults] boolForKey:@"Render3D_Textures"]];
	[self setRender3DDepthComparisonThreshold:(NSUInteger)[[NSUserDefaults standardUserDefaults] integerForKey:@"Render3D_DepthComparisonThreshold"]];
	[self setRender3DLineHack:[[NSUserDefaults standardUserDefaults] boolForKey:@"Render3D_LineHack"]];
	[self setRender3DMultisample:[[NSUserDefaults standardUserDefaults] boolForKey:@"Render3D_Multisample"]];
}

- (IBAction) writeDefaults3DRenderingSettings:(id)sender
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	
	// Force end of editing of any text fields.
	[[(NSControl *)sender window] makeFirstResponder:nil];
	
	[[NSUserDefaults standardUserDefaults] setInteger:[cdsCore.cdsGPU render3DRenderingEngine] forKey:@"Render3D_RenderingEngine"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore.cdsGPU render3DHighPrecisionColorInterpolation] forKey:@"Render3D_HighPrecisionColorInterpolation"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore.cdsGPU render3DEdgeMarking] forKey:@"Render3D_EdgeMarking"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore.cdsGPU render3DFog] forKey:@"Render3D_Fog"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore.cdsGPU render3DTextures] forKey:@"Render3D_Textures"];
	[[NSUserDefaults standardUserDefaults] setInteger:[cdsCore.cdsGPU render3DDepthComparisonThreshold] forKey:@"Render3D_DepthComparisonThreshold"];
	[[NSUserDefaults standardUserDefaults] setInteger:[cdsCore.cdsGPU render3DThreads] forKey:@"Render3D_Threads"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore.cdsGPU render3DLineHack] forKey:@"Render3D_LineHack"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore.cdsGPU render3DMultisample] forKey:@"Render3D_Multisample"];
}

- (IBAction) writeDefaultsEmulationSettings:(id)sender
{
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	NSDictionary *firmwareDict = [(CocoaDSFirmware *)[firmwarePanelController content] dataDictionary];
	
	// Force end of editing of any text fields.
	[[(NSControl *)sender window] makeFirstResponder:nil];
	
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore emuFlagAdvancedBusLevelTiming] forKey:@"Emulation_AdvancedBusLevelTiming"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore emuFlagRigorousTiming] forKey:@"Emulation_RigorousTiming"];
	[[NSUserDefaults standardUserDefaults] setInteger:[cdsCore cpuEmulationEngine] forKey:@"Emulation_CPUEmulationEngine"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore emuFlagUseExternalBios] forKey:@"Emulation_UseExternalBIOSImages"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore emuFlagEmulateBiosInterrupts] forKey:@"Emulation_BIOSEmulateSWI"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore emuFlagPatchDelayLoop] forKey:@"Emulation_BIOSPatchDelayLoopSWI"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore emuFlagUseExternalFirmware] forKey:@"Emulation_UseExternalFirmwareImage"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore emuFlagFirmwareBoot] forKey:@"Emulation_FirmwareBoot"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore emuFlagEmulateEnsata] forKey:@"Emulation_EmulateEnsata"];
	[[NSUserDefaults standardUserDefaults] setBool:[cdsCore emuFlagDebugConsole] forKey:@"Emulation_UseDebugConsole"];
	
	[[NSUserDefaults standardUserDefaults] setObject:[firmwareDict valueForKey:@"Nickname"] forKey:@"FirmwareConfig_Nickname"];
	[[NSUserDefaults standardUserDefaults] setObject:[firmwareDict valueForKey:@"Message"] forKey:@"FirmwareConfig_Message"];
	[[NSUserDefaults standardUserDefaults] setObject:[firmwareDict valueForKey:@"FavoriteColor"] forKey:@"FirmwareConfig_FavoriteColor"];
	[[NSUserDefaults standardUserDefaults] setObject:[firmwareDict valueForKey:@"Birthday"] forKey:@"FirmwareConfig_Birthday"];
	[[NSUserDefaults standardUserDefaults] setObject:[firmwareDict valueForKey:@"Language"] forKey:@"FirmwareConfig_Language"];
}

- (IBAction) writeDefaultsSoundSettings:(id)sender
{
	NSMutableDictionary *speakerBindings = (NSMutableDictionary *)[cdsSoundController content];
	
	[[NSUserDefaults standardUserDefaults] setFloat:[[speakerBindings valueForKey:@"volume"] floatValue] forKey:@"Sound_Volume"];
	[[NSUserDefaults standardUserDefaults] setInteger:[[speakerBindings valueForKey:@"audioOutputEngine"] integerValue] forKey:@"Sound_AudioOutputEngine"];
	[[NSUserDefaults standardUserDefaults] setBool:[[speakerBindings valueForKey:@"spuAdvancedLogic"] boolValue] forKey:@"SPU_AdvancedLogic"];
	[[NSUserDefaults standardUserDefaults] setInteger:[[speakerBindings valueForKey:@"spuInterpolationMode"] integerValue] forKey:@"SPU_InterpolationMode"];
	[[NSUserDefaults standardUserDefaults] setInteger:[[speakerBindings valueForKey:@"spuSyncMode"] integerValue] forKey:@"SPU_SyncMode"];
	[[NSUserDefaults standardUserDefaults] setInteger:[[speakerBindings valueForKey:@"spuSyncMethod"] integerValue] forKey:@"SPU_SyncMethod"];
}

- (IBAction) closeSheet:(id)sender
{
	NSWindow *sheet = [(NSControl *)sender window];
	NSInteger code = [(NSControl *)sender tag];
	
    [NSApp endSheet:sheet returnCode:code];
}

- (void) didEndFileMigrationSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	NSURL *romURL = (NSURL *)contextInfo;
	NSURL *romSaveURL = [CocoaDSFile romSaveURLFromRomURL:romURL];
	
    [sheet orderOut:self];	
	
	switch (returnCode)
	{
		case NSOKButton:
			[CocoaDSFile moveFileToCurrentDirectory:romSaveURL];
			break;
			
		default:
			break;
	}
	
	[self setIsUserInterfaceBlockingExecution:NO];
	[self setIsShowingFileMigrationDialog:NO];
	[self loadRom:romURL];
	
	// We retained this when we initially put up the sheet, so we need to release it now.
	[romURL release];
}

- (void) didEndSaveStateSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	BOOL result = NO;
	
	[sheet orderOut:self];
	
	switch (returnCode)
	{
		case NSCancelButton: // Cancel
			[self restoreCoreState];
			[self setIsUserInterfaceBlockingExecution:NO];
			[self setIsShowingSaveStateDialog:NO];
			return;
			break;
			
		case COCOA_DIALOG_DEFAULT: // Save
			result = [CocoaDSFile saveState:[self currentSaveStateURL]];
			if (result == NO)
			{
				// Throw an error here...
				return;
			}
			break;
			
		case COCOA_DIALOG_OPTION: // Don't Save
			break;
			
		default:
			break;
	}
	
	[self unloadRom];
	[self setIsUserInterfaceBlockingExecution:NO];
	[self setIsShowingSaveStateDialog:NO];
	
	// We retained this when we initially put up the sheet, so we need to release it now.
	[self setCurrentSaveStateURL:nil];
}

- (void) didEndSaveStateSheetOpen:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[self didEndSaveStateSheet:sheet returnCode:returnCode contextInfo:contextInfo];
	
	NSURL *romURL = (NSURL *)contextInfo;
	[self handleLoadRom:romURL];
	[romURL release];
}

- (void) didEndSaveStateSheetTerminate:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[self didEndSaveStateSheet:sheet returnCode:returnCode contextInfo:contextInfo];
	
	if (returnCode == NSCancelButton)
	{
		[NSApp replyToApplicationShouldTerminate:NO];
	}
	else
	{
		if ([self currentSaveStateURL] == nil)
		{
			[NSApp replyToApplicationShouldTerminate:YES];
		}
	}
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)theItem
{
	BOOL enable = YES;
    SEL theAction = [theItem action];
	CocoaDSCore *cdsCore = (CocoaDSCore *)[cdsCoreController content];
	
	if (theAction == @selector(importRomSave:) ||
		theAction == @selector(exportRomSave:))
    {
		if ([self currentRom] == nil)
		{
			enable = NO;
		}
    }
    else if (theAction == @selector(executeCoreToggle:))
    {
		if ([self currentRom] == nil ||
			![cdsCore masterExecute] ||
			[self isUserInterfaceBlockingExecution])
		{
			enable = NO;
		}
		
		if ([(id)theItem isMemberOfClass:[NSMenuItem class]])
		{
			if ([cdsCore coreState] == CORESTATE_PAUSE)
			{
				[(NSMenuItem*)theItem setTitle:NSSTRING_TITLE_EXECUTE_CONTROL];
			}
			else
			{
				[(NSMenuItem*)theItem setTitle:NSSTRING_TITLE_PAUSE_CONTROL];
			}
		}
		else if ([(id)theItem isMemberOfClass:[NSToolbarItem class]])
		{
			if ([cdsCore coreState] == CORESTATE_PAUSE)
			{
				[(NSToolbarItem*)theItem setLabel:NSSTRING_TITLE_EXECUTE_CONTROL];
				[(NSToolbarItem*)theItem setImage:iconExecute];
			}
			else
			{
				[(NSToolbarItem*)theItem setLabel:NSSTRING_TITLE_PAUSE_CONTROL];
				[(NSToolbarItem*)theItem setImage:iconPause];
			}
		}
    }
	else if (theAction == @selector(executeCore) ||
			 theAction == @selector(pauseCore))
    {
		if ([self currentRom] == nil ||
			![cdsCore masterExecute] ||
			[self isShowingSaveStateDialog])
		{
			enable = NO;
		}
    }
	else if (theAction == @selector(resetCore:))
	{
		if ([self currentRom] == nil || [self isUserInterfaceBlockingExecution])
		{
			enable = NO;
		}
	}
	else if (theAction == @selector(_openRecentDocument:))
	{
		if ([self isShowingSaveStateDialog])
		{
			enable = NO;
		}
	}
	else if (theAction == @selector(openRom:))
	{
		if ([self isRomLoading] || [self isShowingSaveStateDialog])
		{
			enable = NO;
		}
	}
	else if (theAction == @selector(closeRom:))
	{
		if ([self currentRom] == nil || [self isRomLoading] || [self isShowingSaveStateDialog])
		{
			enable = NO;
		}
	}
	else if (theAction == @selector(loadEmuSaveStateSlot:))
	{
		if ([self currentRom] == nil || [self isShowingSaveStateDialog])
		{
			enable = NO;
		}
		else if (![CocoaDSFile saveStateExistsForSlot:[[self currentRom] fileURL] slotNumber:[theItem tag] + 1])
		{
			enable = NO;
		}
	}
	else if (theAction == @selector(saveEmuSaveStateSlot:))
	{
		if ([self currentRom] == nil || [self isShowingSaveStateDialog])
		{
			enable = NO;
		}
		
		if ([(id)theItem isMemberOfClass:[NSMenuItem class]])
		{
			if ([CocoaDSFile saveStateExistsForSlot:[[self currentRom] fileURL] slotNumber:[theItem tag] + 1])
			{
				[(NSMenuItem*)theItem setState:NSOnState];
			}
			else
			{
				[(NSMenuItem*)theItem setState:NSOffState];
			}
		}
	}
	else if (theAction == @selector(changeCoreSpeed:))
	{
		NSInteger speedScalar = (NSInteger)([cdsCore speedScalar] * 100.0);
		
		if ([(id)theItem isMemberOfClass:[NSMenuItem class]])
		{
			if ([theItem tag] == -1)
			{
				if (speedScalar == (NSInteger)(SPEED_SCALAR_HALF * 100.0) ||
					speedScalar == (NSInteger)(SPEED_SCALAR_NORMAL * 100.0) ||
					speedScalar == (NSInteger)(SPEED_SCALAR_DOUBLE * 100.0))
				{
					[(NSMenuItem*)theItem setState:NSOffState];
				}
				else
				{
					[(NSMenuItem*)theItem setState:NSOnState];
				}
			}
			else if (speedScalar == [theItem tag])
			{
				[(NSMenuItem*)theItem setState:NSOnState];
			}
			else
			{
				[(NSMenuItem*)theItem setState:NSOffState];
			}
		}
		else if ([(id)theItem isMemberOfClass:[NSToolbarItem class]])
		{
			if (speedScalar == (NSInteger)(SPEED_SCALAR_DOUBLE * 100.0))
			{
				[(NSToolbarItem*)theItem setLabel:NSSTRING_TITLE_SPEED_1X];
				[(NSToolbarItem*)theItem setTag:100];
				[(NSToolbarItem*)theItem setImage:iconSpeedNormal];
			}
			else
			{
				[(NSToolbarItem*)theItem setLabel:NSSTRING_TITLE_SPEED_2X];
				[(NSToolbarItem*)theItem setTag:200];
				[(NSToolbarItem*)theItem setImage:iconSpeedDouble];
			}
		}
	}
	else if (theAction == @selector(speedLimitDisable:))
	{
		if ([(id)theItem isMemberOfClass:[NSMenuItem class]])
		{
			if ([cdsCore isSpeedLimitEnabled])
			{
				[(NSMenuItem*)theItem setTitle:NSSTRING_TITLE_DISABLE_SPEED_LIMIT];
			}
			else
			{
				[(NSMenuItem*)theItem setTitle:NSSTRING_TITLE_ENABLE_SPEED_LIMIT];
			}
		}
	}
	else if (theAction == @selector(toggleAutoFrameSkip:))
	{
		if ([(id)theItem isMemberOfClass:[NSMenuItem class]])
		{
			if ([cdsCore isFrameSkipEnabled])
			{
				[(NSMenuItem*)theItem setTitle:NSSTRING_TITLE_DISABLE_AUTO_FRAME_SKIP];
			}
			else
			{
				[(NSMenuItem*)theItem setTitle:NSSTRING_TITLE_ENABLE_AUTO_FRAME_SKIP];
			}
		}
	}
	else if (theAction == @selector(cheatsDisable:))
	{
		if ([(id)theItem isMemberOfClass:[NSMenuItem class]])
		{
			if ([cdsCore isCheatingEnabled])
			{
				[(NSMenuItem*)theItem setTitle:NSSTRING_TITLE_DISABLE_CHEATS];
			}
			else
			{
				[(NSMenuItem*)theItem setTitle:NSSTRING_TITLE_ENABLE_CHEATS];
			}
		}
	}
	else if (theAction == @selector(changeRomSaveType:))
	{
		if ([(id)theItem isMemberOfClass:[NSMenuItem class]])
		{
			if ([self selectedRomSaveTypeID] == [theItem tag])
			{
				[(NSMenuItem*)theItem setState:NSOnState];
			}
			else
			{
				[(NSMenuItem*)theItem setState:NSOffState];
			}
		}
	}
	else if (theAction == @selector(openEmuSaveState:) ||
			 theAction == @selector(saveEmuSaveState:) ||
			 theAction == @selector(saveEmuSaveStateAs:))
	{
		if ([self currentRom] == nil || [self isShowingSaveStateDialog])
		{
			enable = NO;
		}
	}
	else if (theAction == @selector(revertEmuSaveState:))
	{
		if ([self currentRom] == nil ||
			[self isShowingSaveStateDialog] ||
			[self currentSaveStateURL] == nil)
		{
			enable = NO;
		}
	}
	else if (theAction == @selector(toggleGPUState:))
	{
		if ([(id)theItem isMemberOfClass:[NSMenuItem class]])
		{
			if ([cdsCore.cdsGPU gpuStateByBit:[theItem tag]])
			{
				[(NSMenuItem*)theItem setState:NSOnState];
			}
			else
			{
				[(NSMenuItem*)theItem setState:NSOffState];
			}
		}
	}
	
	return enable;
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	[self setRender3DDepthComparisonThreshold:[(NSNumber *)[aNotification object] integerValue]];
}

@end
