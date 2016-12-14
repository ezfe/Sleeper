//
//  ViewController.swift
//  Sleeper
//
//  Created by Ezekiel Elin on 12/14/16.
//  Copyright © 2016 Ezekiel Elin. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController {

    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var segment: UISegmentedControl!
    
    var wentToSleep: Date? = nil
    var wokeUp: Date? = nil
    
    var healthStore = HKHealthStore()
    var sharingAuthorized: Bool {
        get {
            return healthStore.authorizationStatus(for: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!) == .sharingAuthorized
        }
    }
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let readTypes: Set<HKSampleType> = [sleepType]
        let writeTypes: Set<HKSampleType> = [sleepType]
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { (success, error) in
            if error != nil {
                print(error?.localizedDescription ?? "Error")
            } else {
                print("Status: \(success)")
            }
        }
        
        segment.selectedSegmentIndex = 0
        segment.setEnabled(false, forSegmentAt: 1)
    }
    
    @IBAction func onDidChangeDate(sender: UIDatePicker) {
        switch segment.selectedSegmentIndex {
        case 0:
            wentToSleep = datePicker.date
        case 1:
            wokeUp = datePicker.date
        default:
            break
        }
    }
    
    @IBAction func segmentChanged(sender: UISegmentedControl) {
        switch segment.selectedSegmentIndex {
        case 0:
            if let date = wentToSleep {
                datePicker.date = date
            }
        case 1:
            if let date = wokeUp {
                datePicker.date = date
            } else if let date = wentToSleep {
                datePicker.date = date.addingTimeInterval(28800)
            }
        default:
            break
        }

    }

    @IBAction func makeDateNow(sender: UIButton) {
        datePicker.date = Date()
    }
    
    @IBAction func saveSleep(sender: UIButton) {
        switch segment.selectedSegmentIndex {
        case 0:
            wentToSleep = datePicker.date
            segment.setEnabled(true, forSegmentAt: 1)
            segment.selectedSegmentIndex = 1
            if let date = wokeUp {
                datePicker.date = date
            } else {
                datePicker.date = datePicker.date.addingTimeInterval(28800)
                wokeUp = datePicker.date
            }
        case 1:
            wokeUp = datePicker.date
            segment.selectedSegmentIndex = 0
            segment.setEnabled(false, forSegmentAt: 1)
            saveSleepAnalysis()
        default:
            break
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func saveSleepAnalysis() {
        
        if sharingAuthorized {
            let inBedValue = HKCategoryValueSleepAnalysis.inBed.rawValue
            let object = HKCategorySample(type: sleepType, value: inBedValue, start: Date(), end: Date())
            
            healthStore.save(object, withCompletion: { (success, error) in
                if error != nil {
                    print(error?.localizedDescription ?? "Error")
                } else {
                    print("Write: \(success)")
                }
            })
        }
        
    }

}

