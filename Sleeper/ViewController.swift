//
//  ViewController.swift
//  Sleeper
//
//  Created by Ezekiel Elin on 12/14/16.
//  Copyright © 2016 Ezekiel Elin. All rights reserved.
//

import UIKit
import HealthKit
import UserNotifications

class ViewController: UIViewController, UNUserNotificationCenterDelegate {
    
    let defaults = UserDefaults.standard
    
    @IBOutlet var sleepButton: UIButton!
    @IBOutlet var sleepAt: UIButton!
    @IBOutlet var wakeButton: UIButton!
    @IBOutlet var wakeAtButton: UIButton!
    @IBOutlet var wakeAtSaveButton: UIBarButtonItem!
    @IBOutlet var openHealthButton: UIBarButtonItem!
    
    @IBOutlet var sleepLabel: UILabel!
    
    @IBOutlet var wakeAtPicker: UIDatePicker!
    
    @IBOutlet var saveIndicator: UIActivityIndicatorView!
    
    @IBOutlet var cancelButton: UIBarButtonItem!
    
    let bedToSleep: TimeInterval = 60*15 /* 15 minutes */
    let sleepToBed: TimeInterval = 60*5 /* 5 minutes */
    
    var healthStore = HKHealthStore()
    var sharingAuthorized: Bool {
        get {
            return healthStore.authorizationStatus(for: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!) == .sharingAuthorized
        }
    }
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    var sleepPressedAt: Date? = nil {
        didSet {
            defaults.set(sleepPressedAt, forKey: "wentToSleep")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let readTypes: Set<HKSampleType> = [sleepType]
        let writeTypes: Set<HKSampleType> = [sleepType]
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { (success, error) in
            if error != nil {
                print(error?.localizedDescription ?? "Error")
            } else {
                print("Health Status: \(success ? "Enabled" : "Disabled")")
            }
        }
        
        sleepPressedAt = defaults.object(forKey: "wentToSleep") as? Date
        
        if let _ = sleepPressedAt {
            refreshUI(sleeping: true)
        } else {
            refreshUI(sleeping: false)
        }
    }
    
    func save(_ type: HKCategoryValueSleepAnalysis, from startDate: Date, to endDate: Date, completion: @escaping (Bool, Error?) -> Void) {
        let sample = HKCategorySample(type: sleepType, value: type.rawValue, start: startDate, end: endDate)
        healthStore.save(sample) { (success, error) in
            completion(success, error)
        }
    }
    
    func save(from bedStart: Date, to bedEnd: Date) {
        DispatchQueue.main.async {
            self.hideAll()
            self.saveIndicator.startAnimating()
            
            let sleepStart = bedStart.addingTimeInterval(self.bedToSleep)
            let sleepEnd = bedEnd.addingTimeInterval(-self.sleepToBed)
            
            /* Check if we can save in-bed */
            if bedEnd > bedStart {
                self.save(.inBed, from: bedStart, to: bedEnd, completion: { (bedSuccess, bedError) in
                    
                    /* Check if we can save sleep */
                    if sleepEnd > sleepStart {
                        self.save(.asleep, from: sleepStart, to: sleepEnd, completion: { (sleepSuccess, sleepError) in
                            let alertTitle = "Unable to Save"
                            var alertString = "An unknown issue occurred"
                            
                            if !sleepSuccess || !bedSuccess {
                                if let error = sleepError, !sleepSuccess {
                                    alertString = "\(error)"
                                } else {
                                    if let error = bedError, !bedSuccess {
                                        alertString = "\(error)"
                                    }
                                }
                                
                                self.alertUser(title: alertTitle, body: alertString)
                            } else {
                                print("Saved all Health information")
                            }
                            
                            self.sleepPressedAt = nil
                            self.refreshUI(sleeping: false)
                        })
                    } else {
                        /* we cannot save sleep, but we can save in-bed */
                        self.alertUser(title: "Only Saved In-Bed", body: "You cannot sleep for less than 20 minutes")
                        
                        print("Cancelled due to 20 minute timer (asleep)")
                        
                        self.sleepPressedAt = nil
                        self.refreshUI(sleeping: false)
                    }
                })
            } else {
                /* We cannot save in-bed or sleep */
                self.alertUser(title: "Unable to Save", body: "You were in bed for negative time")
                
                print("Cancelled due to 20 minute timer (in-bed)")
                
                self.sleepPressedAt = nil
                self.refreshUI(sleeping: false)
            }
        }
    }
    
    func refreshUI(sleeping: Bool) {
        sleepButton.isHidden = sleeping
        sleepAt.isHidden = sleeping
        wakeButton.isHidden = !sleeping
        wakeAtButton.isHidden = !sleeping
        sleepLabel.isHidden = !sleeping
        
        openHealthButton.isEnabled = true
        wakeAtPicker.isHidden = true
        wakeAtSaveButton.isEnabled = false
        
        saveIndicator.stopAnimating()
        
        cancelButton.isEnabled = sleeping
        
        if let date = sleepPressedAt, sleeping {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let formatted = formatter.string(from: date)
            sleepLabel.text = "Sleeping since \(formatted)"
        }
        
        let icon = UIApplicationShortcutIcon(type: .time)
        
        let sleep = UIApplicationShortcutItem(type: "com.ezekielelin.sleeper.sleep", localizedTitle: "Sleep", localizedSubtitle: nil, icon: icon, userInfo: nil)
        let wake = UIApplicationShortcutItem(type: "com.ezekielelin.sleeper.wake", localizedTitle: "Wake", localizedSubtitle: nil, icon: icon, userInfo: nil)
        
        if sleeping {
            UIApplication.shared.shortcutItems = [wake]
        } else {
            UIApplication.shared.shortcutItems = [sleep]
        }
    }
    
    func hideAll() {
        sleepButton.isHidden = true
        sleepAt.isHidden = true
        wakeButton.isHidden = true
        wakeAtButton.isHidden = true
        sleepLabel.isHidden = true
        
        saveIndicator.stopAnimating()
        
        openHealthButton.isEnabled = false
        wakeAtPicker.isHidden = true
        wakeAtSaveButton.isEnabled = false
        
        cancelButton.isEnabled = false
    }
    
    @IBAction func sleepButtonPress() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        let wakeUp = UNNotificationAction(identifier: "com.ezekielelin.sleeper.notification.wake.action", title: "Wake Up")
        let category = UNNotificationCategory(identifier: "com.ezekielelin.sleeper.notification.wake", actions: [wakeUp], intentIdentifiers: [])
        
        center.setNotificationCategories([category])
        
        let now = Date()
        
        center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            if granted {
                center.removeAllPendingNotificationRequests()
                center.removeAllDeliveredNotifications()
                
                let notif = now.addingTimeInterval(60*30) //Half an hour from now
                
                let flags: Set<Calendar.Component> = [.hour, .minute, .second, .year, .month, .day, .calendar]
                let componenet = Calendar.current.dateComponents(flags, from: notif)
                
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: componenet, repeats: false)
                
                let content = UNMutableNotificationContent()
                content.title = "Wake Up"
                content.body = "Press to wake up from sleep"
                content.categoryIdentifier = "com.ezekielelin.sleeper.notification.wake"
                content.sound = UNNotificationSound.default()
                
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                
                center.add(request)
            } else {
                self.alertUser(title: "Unable to Schedule Notifications", body: "You must enable notifications in Settings")
            }
        }
        
        sleepPressedAt = now
        refreshUI(sleeping: true)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            wakeButtonPress()
        case "com.ezekielelin.sleeper.notification.wake.action":
            wakeButtonPress()
        default:
            print("Unknown action")
        }
        
        completionHandler()
    }
    
    @IBAction func wakeButtonPress() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        if let bedStart = sleepPressedAt {
            save(from: bedStart, to: Date())
        } else {
            sleepPressedAt = nil
            refreshUI(sleeping: false)
        }
    }
    
    @IBAction func sleepAtButtonPress() {
        hideAll()
        
        cancelButton.isEnabled = true
        
        wakeAtPicker.date = Date().addingTimeInterval(-8*60*60)
        
        wakeAtPicker.isHidden = false
        wakeAtSaveButton.isEnabled = true
    }
    
    @IBAction func wakeAtButtonPress() {
        hideAll()
        
        cancelButton.isEnabled = true
        
        wakeAtPicker.date = sleepPressedAt?.addingTimeInterval(8*60*60) ?? Date()
        
        wakeAtPicker.isHidden = false
        wakeAtSaveButton.isEnabled = true
    }
    
    @IBAction func wakeAtSaveButtonPressed() {
        let pickerDate = wakeAtPicker.date
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        if let bedStart = sleepPressedAt {
            save(from: bedStart, to: pickerDate)
        } else {
            sleepPressedAt = pickerDate
            refreshUI(sleeping: true)
        }
    }
    
    @IBAction func openHealthApp() {
        UIApplication.shared.open(URL(string: "x-apple-health://")!)
    }
    
    func alertUser(title: String, body: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func cancelButtonPressed() {
        sleepPressedAt = nil
        refreshUI(sleeping: false)
    }
}

