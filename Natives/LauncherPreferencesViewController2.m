#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "DBNumberedSlider.h"
#import "LauncherPreferences.h"
#import "LauncherPreferencesViewController2.h"
#import "LauncherPrefGameDirViewController.h"
#import "TOInsetGroupedTableView.h"

#include "utils.h"

typedef void(^CreateView)(UITableViewCell *, NSString *, NSDictionary *);

@interface LauncherPreferencesViewController2()<UIPickerViewDataSource, UIPickerViewDelegate> {}
@property NSArray<NSString*>* prefSections;
@property NSArray<NSArray<NSDictionary*>*>* prefContents;

@property CreateView typeButton, typeChildPane, typePickField, typeTextField, typeSlider, typeSwitch;
@end

@implementation LauncherPreferencesViewController2

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self initViewCreation];

    self.tableView = [[TOInsetGroupedTableView alloc] init];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.sectionHeaderHeight = 50;

    BOOL(^whenNotInGame)() = ^BOOL(){
        return self.navigationController != nil;
    };

    self.prefSections = @[@"general", @"video", @"control", @"java"];

    self.prefContents = @[
        @[
        // General settings
            @{@"key": @"game_directory",
                @"icon": @"folder",
                @"type": self.typeChildPane,
                @"enableCondition": whenNotInGame,
                @"class": LauncherPrefGameDirViewController.class,
            },
            @{@"key": @"home_symlink",
                @"icon": @"link",
                @"type": self.typeSwitch,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"check_sha",
                @"icon": @"lock.shield",
                @"type": self.typeSwitch,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"cosmetica",
                @"icon": @"eyeglasses",
                @"type": self.typeSwitch,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"reset_warnings",
                @"icon": @"exclamationmark.triangle",
                @"type": self.typeButton,
                @"enableCondition": whenNotInGame,
                @"action": ^void(){
                    resetWarnings();
                }
            },
            @{@"key": @"reset_settings",
                @"icon": @"trash",
                @"type": self.typeButton,
                @"enableCondition": whenNotInGame,
                @"requestReload": @YES,
                @"showConfirmPrompt": @YES,
                @"destructive": @YES,
                @"action": ^void(){
                    loadPreferences(YES);
                    [self.tableView reloadData];
                }
            },
        ], @[
        // Video and renderer settings
            @{@"key": @"renderer",
                @"icon": @"cpu",
                @"type": self.typePickField,
                @"enableCondition": whenNotInGame,
                @"pickKeys": @[
                    @"auto",
                    @ RENDERER_NAME_GL4ES,
                    @ RENDERER_NAME_MTL_ANGLE,
                    @ RENDERER_NAME_VK_ZINK
                ],
                @"pickList": @[
                    NSLocalizedString(@"preference.title.renderer.auto", nil),
                    NSLocalizedString(@"preference.title.renderer.gl4es", nil),
                    NSLocalizedString(@"preference.title.renderer.tinygl4angle", nil),
                    NSLocalizedString(@"preference.title.renderer.zink", nil)
                ]
            },
            @{@"key": @"resolution",
                @"icon": @"viewfinder",
                @"type": self.typeSlider,
                @"enableCondition": whenNotInGame,
                @"min": @(25),
                @"max": @(150)
            },
        ], @[
        // Control settings
        /*
            @"disable_gesture": @{
                @"type": self.typeSwitch
            },
        */
            @{@"key": @"press_duration",
                @"icon": @"timer",
                @"type": self.typeSlider,
                @"min": @(100),
                @"max": @(1000)
            },
            @{@"key": @"button_scale",
                @"icon": @"aspectratio",
                @"type": self.typeSlider,
                @"min": @(50), // 80?
                @"max": @(500)
            },
            @{@"key": @"mouse_scale",
                @"icon": @"arrow.up.left.and.arrow.down.right.circle",
                @"type": self.typeSlider,
                @"min": @(25),
                @"max": @(300)
            },
            @{@"key": @"mouse_speed",
                @"icon": @"arrow.left.and.right",
                @"type": self.typeSlider,
                @"min": @(25),
                @"max": @(300)
            },
            @{@"key": @"virtmouse_enable",
                @"icon": @"cursorarrow.rays",
                @"type": self.typeSwitch
            },
            @{@"key": @"slideable_hotbar",
                @"icon": @"slider.horizontal.below.rectangle",
                @"type": self.typeSwitch
            }
        ], @[
        // Java tweaks
            @{@"key": @"java_home", // TODO: name as Use Java 17 for older MC
                @"icon": @"cube",
                @"type": self.typeSwitch,
                @"enableCondition": whenNotInGame,
                // false: 8, true: 17
                @"customSwitchValue": @[@"java-8-openjdk", @"java-17-openjdk"]
            },
            @{@"key": @"java_args",
                @"icon": @"slider.vertical.3",
                @"type": self.typeTextField,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"auto_ram",
                @"icon": @"slider.horizontal.3",
                @"type": self.typeSwitch,
                @"enableCondition": whenNotInGame,
                //@"hidden": @(getenv("POJAV_DETECTEDJB") == NULL),
                @"requestReload": @YES
            },
            @{@"key": @"allocated_memory",
                @"icon": @"memorychip",
                @"type": self.typeSlider,
                @"min": @(NSProcessInfo.processInfo.physicalMemory / 1048576 * 0.25),
                @"max": @(NSProcessInfo.processInfo.physicalMemory / 1048576 * 0.85),
                @"enableCondition": ^BOOL(){
                    return ![getPreference(@"auto_ram") boolValue] && whenNotInGame();
                },
                @"warnAlways": @NO,
                @"warnCondition": ^BOOL(DBNumberedSlider *view){
                    return view.value >= NSProcessInfo.processInfo.physicalMemory / 1048576 * 0.4;
                },
                @"warnKey": @"mem_warn"
            }
        ]
    ];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Scan for child pane cells and reload them
    // FIXME: any cheaper operations?
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    for (int section = 0; section < self.prefContents.count; section++) {
        for (int row = 0; row < self.prefContents[section].count; row++) {
            if (self.prefContents[section][row][@"type"] == self.typeChildPane) {
                [indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:section]];
            }
        }
    }
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
}

- (void)dismissViewController {
    [self.presentingViewController performSelector:@selector(updatePreferenceChanges)];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.prefSections.count;
}

- (UIView *)tableView:(UITableView *)tableView 
viewForHeaderInSection:(NSInteger)section {
    if (section != 0 || self.navigationController != nil) {
        return nil;
    }

    UIButton *doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [doneButton setTitle:NSLocalizedString(@"Done", nil) forState:UIControlStateNormal];
    [doneButton addTarget:self action:@selector(dismissViewController) forControlEvents:UIControlEventTouchUpInside];
    return doneButton;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return NSLocalizedString(([NSString stringWithFormat:@"preference.section.%@", self.prefSections[section]]), nil);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.prefContents[section].count;
}

- (UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    // Reset cell properties, as it could be reused
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.textColor = nil;
    cell.detailTextLabel.text = nil;

    NSDictionary *item = self.prefContents[indexPath.section][indexPath.row];
    NSString *key = item[@"key"];
    CreateView createView = item[@"type"];
    createView(cell, key, item);
    if (cell.accessoryView) {
        objc_setAssociatedObject(cell.accessoryView, @"key", key, OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(cell.accessoryView, @"item", item, OBJC_ASSOCIATION_ASSIGN);
    }

    // Set general properties
    if (@available(iOS 13.0, *)) {
        BOOL destructive = [item[@"destructive"] boolValue];
        cell.imageView.tintColor = destructive ? UIColor.systemRedColor : nil;
        cell.imageView.image = [UIImage systemImageNamed:item[@"icon"]];
    }
    cell.textLabel.text = NSLocalizedString(([NSString stringWithFormat:@"preference.title.%@", key]), nil);

    // Check if one has enable condition and call if it does
    BOOL(^checkEnable)(void) = item[@"enableCondition"];
    cell.userInteractionEnabled = !checkEnable || checkEnable();
    cell.textLabel.enabled = cell.detailTextLabel.enabled = cell.userInteractionEnabled;
    [(id)cell.accessoryView setEnabled:cell.userInteractionEnabled];

    return cell;
}

- (void)initViewCreation {
    __weak LauncherPreferencesViewController2 *weakSelf = self;

    self.typeButton = ^void(UITableViewCell *cell, NSString *key, NSDictionary *item) {
        BOOL destructive = [item[@"destructive"] boolValue];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.textLabel.textColor = destructive ? UIColor.systemRedColor : UIColor.systemBlueColor;
    };

    self.typeChildPane = ^void(UITableViewCell *cell, NSString *key, NSDictionary *item) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.detailTextLabel.text = getPreference(key);
    };

/*
    self.typePickField = ^void(UITableViewCell *cell, NSString *key, NSDictionary *item) {
        cell.accessoryView = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, cell.bounds.size.width / 2, cell.bounds.size.height)];
        [(id)(cell.accessoryView) setText:getPreference(key)];
    };
*/

    self.typeTextField = ^void(UITableViewCell *cell, NSString *key, NSDictionary *item) {
        UITextField *view = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, cell.bounds.size.width / 2.1, cell.bounds.size.height)];
        [view addTarget:view action:@selector(resignFirstResponder) forControlEvents:UIControlEventEditingDidEndOnExit];
        view.autocorrectionType = UITextAutocorrectionTypeNo;
        view.autocapitalizationType = UITextAutocapitalizationTypeNone;
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
        view.delegate = weakSelf;
        view.placeholder = NSLocalizedString(([NSString stringWithFormat:@"preference.placeholder.%@", key]), nil);
        view.returnKeyType = UIReturnKeyDone;
        view.text = getPreference(key);
        view.textAlignment = NSTextAlignmentRight;
        view.adjustsFontSizeToFitWidth = YES;
        cell.accessoryView = view;
    };

    self.typePickField = ^void(UITableViewCell *cell, NSString *key, NSDictionary *item) {
        weakSelf.typeTextField(cell, key, item);
        UITextField *view = (UITextField *)cell.accessoryView;
        UIPickerView *picker = [[UIPickerView alloc] init];
        objc_setAssociatedObject(picker, @"item", item, OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(picker, @"view", cell.accessoryView, OBJC_ASSOCIATION_ASSIGN);
        picker.delegate = weakSelf;
        picker.dataSource = weakSelf;
        [picker reloadAllComponents];
        [picker selectRow:[item[@"pickKeys"] indexOfObject:getPreference(key)] inComponent:0 animated:NO];
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0, 0.0, weakSelf.view.frame.size.width, 44.0)];
        UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:view action:@selector(resignFirstResponder)];
        toolbar.items = @[flexibleSpace, doneButton];
        view.inputAccessoryView = toolbar;
        view.inputView = picker;
    };

    self.typeSlider = ^void(UITableViewCell *cell, NSString *key, NSDictionary *item) {
        DBNumberedSlider *view = [[DBNumberedSlider alloc] initWithFrame:CGRectMake(0, 0, cell.bounds.size.width / 2.1, cell.bounds.size.height)];
        [view addTarget:weakSelf action:@selector(sliderMoved:) forControlEvents:UIControlEventValueChanged];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
        view.minimumValue = [item[@"min"] intValue];
        view.maximumValue = [item[@"max"] intValue];
        view.continuous = YES;
        view.value = [getPreference(key) intValue];
        cell.accessoryView = view;
    };

    self.typeSwitch = ^void(UITableViewCell *cell, NSString *key, NSDictionary *item) {
        UISwitch *view = [[UISwitch alloc] init];
        NSArray *customSwitchValue = item[@"customSwitchValue"];
        if (customSwitchValue == nil) {
            [view setOn:[getPreference(key) boolValue] animated:NO];
        } else {
            [view setOn:[getPreference(key) isEqualToString:customSwitchValue[1]] animated:NO];
        }
        [view addTarget:weakSelf action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = view;
    };
}

- (void)showAlertOnView:(UIView *)view title:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];
    alert.popoverPresentationController.sourceView = view;
    alert.popoverPresentationController.sourceRect = view.bounds;
    UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)checkWarn:(UIView *)view {
    NSDictionary *item = objc_getAssociatedObject(view, @"item");
    NSString *key = item[@"key"];

    BOOL(^isWarnable)(UIView *) = item[@"warnCondition"];
    NSString *warnKey = item[@"warnKey"];
    if (isWarnable && isWarnable(view) && (!warnKey || [getPreference(warnKey) boolValue])) {
        if (warnKey) {
            setPreference(warnKey, @NO);
        }

        NSString *message = NSLocalizedString(([NSString stringWithFormat:@"preference.warn.%@", key]), nil);
        [self showAlertOnView:view title:NSLocalizedString(@"Warning", nil) message:message];
    }
}

#pragma mark - UIPickerView

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSDictionary *item = objc_getAssociatedObject(pickerView, @"item");
    UITextField *view = objc_getAssociatedObject(pickerView, @"view");

    // If there is key, use it
    if (item[@"pickKeys"] != nil) {
        view.text = item[@"pickKeys"][row];
    } else {
        view.text = item[@"pickList"][row];
    }

    // Save the preference
    [self textFieldDidEndEditing:view];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)thePickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSDictionary *item = objc_getAssociatedObject(pickerView, @"item");
    return [item[@"pickList"] count];
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSDictionary *item = objc_getAssociatedObject(pickerView, @"item");
    return item[@"pickList"][row];
}

#pragma mark Control event handlers

- (void)sliderMoved:(DBNumberedSlider *)sender {
    [self checkWarn:sender];
    NSString *key = objc_getAssociatedObject(sender, @"key");

    sender.value = (int)sender.value;
    setPreference(key, @(sender.value));
}

- (void)switchChanged:(UISwitch *)sender {
    [self checkWarn:sender];
    NSDictionary *item = objc_getAssociatedObject(sender, @"item");
    NSString *key = item[@"key"];

    // Special switches may define custom value instead of NO/YES
    NSArray *customSwitchValue = item[@"customSwitchValue"];
    if (customSwitchValue != nil) {
        setPreference(key, customSwitchValue[sender.isOn]);
    } else {
        setPreference(key, @(sender.isOn));
    }

    // Some settings may affect the availability of other settings
    // In this case, a switch may request to reload to apply user interaction change
    if ([item[@"requestReload"] boolValue]) {
        // TODO: only reload needed rows
        [self.tableView reloadData];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];

    NSDictionary *item = self.prefContents[indexPath.section][indexPath.row];

    if (item[@"type"] == self.typeButton) {
        [self tableView:tableView invokeActionWithPromptAtIndexPath:indexPath];
    } else if (item[@"type"] == self.typeChildPane) {
        [self tableView:tableView openChildPaneAtIndexPath:indexPath];
    }
}

#pragma mark External UITableView functions

- (void)tableView:(UITableView *)tableView openChildPaneAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.prefContents[indexPath.section][indexPath.row];
    UIViewController *vc = [[item[@"class"] alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)tableView:(UITableView *)tableView invokeActionWithPromptAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *view = [self.tableView cellForRowAtIndexPath:indexPath];
    NSDictionary *item = self.prefContents[indexPath.section][indexPath.row];
    NSString *key = item[@"key"];

    if ([item[@"showConfirmPrompt"] boolValue]) {
        BOOL destructive = [item[@"destructive"] boolValue];
        NSString *title = NSLocalizedString(@"preference.title.confirm", nil);
        NSString *message = NSLocalizedString(([NSString stringWithFormat:@"preference.title.confirm.%@", key]), nil);
        UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];
        confirmAlert.popoverPresentationController.sourceView = view;
        confirmAlert.popoverPresentationController.sourceRect = view.bounds;
        UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:destructive?UIAlertActionStyleDestructive:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self tableView:tableView invokeActionAtIndexPath:indexPath];
        }];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil];
        [confirmAlert addAction:cancel];
        [confirmAlert addAction:ok];
        [self presentViewController:confirmAlert animated:YES completion:nil];
    } else {
        [self tableView:tableView invokeActionAtIndexPath:indexPath];
    }
}

- (void)tableView:(UITableView *)tableView invokeActionAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.prefContents[indexPath.section][indexPath.row];
    NSString *key = item[@"key"];

    void(^invokeAction)(void) = item[@"action"];
    if (invokeAction) {
        invokeAction();
    }

    UIView *view = [self.tableView cellForRowAtIndexPath:indexPath];
    NSString *title = NSLocalizedString(([NSString stringWithFormat:@"preference.title.done.%@", key]), nil);
    //NSString *message = NSLocalizedString(([NSString stringWithFormat:@"preference.message.done.%@", key]), nil);
    [self showAlertOnView:view title:title message:nil];
}

#pragma mark UITextField

- (void)textFieldDidEndEditing:(UITextField *)sender {
    [self checkWarn:sender];
    NSString *key = objc_getAssociatedObject(sender, @"key");

    setPreference(key, sender.text);
}

@end
