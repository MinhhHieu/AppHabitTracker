
import SwiftUI
import CoreData
import UserNotifications

class HabitViewModel: ObservableObject {
    @Published var addNewHabit: Bool = false
    
    @Published var title: String = ""
    @Published var habitColor: String = "Card-1"
    @Published var weekDays: [String] = []
    @Published var isRemainderOn: Bool = false
    @Published var remainderText: String = ""
    @Published var remainderDate: Date = Date()
    @Published var showTimePicker: Bool = false
    
    @Published var editHabit: Habit?
    
    @Published var notificationAccess: Bool = false
    init(){
        requestNotificationAccess()
    }
    func requestNotificationAccess(){
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound,.alert]){ status, _ in
            DispatchQueue.main.async {
                self.notificationAccess = status
            }
        }
    }
    
    func addHabit(context: NSManagedObjectContext) async -> Bool{
        var habit: Habit!
        if let editHabit = editHabit{
            habit = editHabit
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: editHabit.notificationIDs ?? [])
        }else{
            habit = Habit(context: context)
        }
        habit.title = title
        habit.color = habitColor
        habit.weekDays = weekDays
        habit.isRemainderOn = isRemainderOn
        habit.remainderText = remainderText
        habit.notificationDate = remainderDate
        habit.notificationIDs = []
        
        if isRemainderOn{
            if let ids = try? await scheduleNotification(){
                habit.notificationIDs = ids
                if let _ = try? context.save(){
                    return true
                }
            }
        }else{
            if let _ = try? context.save(){
                return true
            }
        }
        return false
    }
    
    func scheduleNotification()async throws -> [String]{
        let content = UNMutableNotificationContent()
        content.title = "Habit Remainder"
        content.subtitle = remainderText
        content.sound = UNNotificationSound.default
        
        var notificationIDs: [String] = []
        let calendar = Calendar.current
        let weekdaySymbols: [String] = calendar.weekdaySymbols
        
        for weekDay in weekDays {
            let id = UUID().uuidString
            let hour = calendar.component(.hour, from: remainderDate)
            let min = calendar.component(.minute, from: remainderDate)
            let day = weekdaySymbols.firstIndex{ currentDay in
                return currentDay == weekDay
            } ?? -1

            if day != -1{
                var components = DateComponents()
                components.hour = hour
                components.minute = min
                components.weekday = day + 1
            
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

                try await UNUserNotificationCenter.current().add(request)
                notificationIDs.append(id)
            }
        }
        
        return notificationIDs
    }
    
    func resetData(){
        title = ""
        habitColor = "Card-1"
        weekDays = []
        isRemainderOn = false
        remainderDate = Date()
        remainderText = ""
        editHabit = nil
    }
    
    func deleteHabit(context: NSManagedObjectContext) -> Bool{
        if let editHabit = editHabit{
            if editHabit.isRemainderOn{
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: editHabit.notificationIDs ?? [])
            }
            context.delete(editHabit)
            if let _ = try? context.save(){
                return true
            }
        }
        
        return false
    }
    
    func restoreEditData(){
        if let editHabit = editHabit{
            title = editHabit.title ?? ""
            habitColor = editHabit.color ?? "Card-1"
            weekDays = editHabit.weekDays ?? []
            isRemainderOn = editHabit.isRemainderOn
            remainderDate = editHabit.notificationDate ?? Date()
            remainderText = editHabit.remainderText ?? ""
        }
    }
    
    func doneStatus() -> Bool {
        let remainderStatus = isRemainderOn ? remainderText == "" : false
        
        if title == "" || weekDays.isEmpty || remainderStatus{
            return false
        }
        return true
    }
}



