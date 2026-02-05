import SwiftUI

struct NotificationView: View {
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.presentationMode) var presentationMode
    
    private let lastDeniedKey = "lastNotificationDeniedDate"
    
    var isPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }
    
    var isLandscape: Bool {
        verticalSizeClass == .compact && horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack {
            if isPortrait {
                ZStack {
                    Image("bglnotport")
                        .resizable()
                        .ignoresSafeArea()
                    
                    VStack(spacing: 30) {
                        Spacer()
                        
                        VStack(spacing: 20) {
                            Image("all")
                                 .resizable()
                                 .aspectRatio(contentMode: .fit)
                            
                           Image("stay")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                        .padding(.horizontal, 40)
                        
                        VStack(spacing: 10) {
                            Button(action: {
                                requestNotificationPermission()
                            }) {
                                Image("bonuses")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 350, height: 60)
                            }
                            
                            Button(action:{
                                saveDeniedDate()
                                presentationMode.wrappedValue.dismiss()
                                NotificationCenter.default.post(name: .notificationPermissionResult, object: nil, userInfo: ["granted": true])
                            }) {
                                Image("skip")
                                    .resizable()
                                    .frame(width: 50, height: 20)
                            }
                        }
                    }
                    .padding(.vertical, 20)
                }
            } else {
                ZStack {
                    Image("bgland")
                        .resizable()
                        .ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
                        HStack {
                            
                            VStack(alignment: .leading, spacing: 15) {
                                Image("all")
                                     .resizable()
                                     .aspectRatio(contentMode: .fit)
                                     .frame(width: 300, height: 40)
                                
                                Image("stay")
                                     .resizable()
                                     .aspectRatio(contentMode: .fit)
                                     .frame(width: 250, height: 30)
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 10) {
                                Button(action: {
                                    requestNotificationPermission()
                                }) {
                                    Image("bonuses")
                                        .resizable()
                                        .frame(width: 360, height: 60)
                                }
                                
                                Button(action:{
                                    saveDeniedDate()
                                    presentationMode.wrappedValue.dismiss()
                                    NotificationCenter.default.post(name: .notificationPermissionResult, object: nil, userInfo: ["granted": true])
                                }) {
                                    Image("skip")
                                        .resizable()
                                        .frame(width: 50, height: 20)
                                }
                            }
                        }
                        .padding(.bottom, 10)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if granted {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .notificationPermissionResult, object: nil, userInfo: ["granted": true])
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        saveDeniedDate()
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .notificationPermissionResult, object: nil, userInfo: ["granted": false])
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            case .denied:
                presentationMode.wrappedValue.dismiss()
            case .authorized, .provisional, .ephemeral:
                print("razresheni")
            @unknown default:
                break
            }
        }
    }
    
    private func saveDeniedDate() {
        UserDefaults.standard.set(Date(), forKey: lastDeniedKey)
        print("Saved last denied date: \(Date())")
    }
}

#Preview {
    NotificationView()
}
