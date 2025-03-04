//
//  AppDelegate.swift
//  Sluv2
//
//  Created by 장윤정 on 2024/02/05.
//

import UIKit
import IQKeyboardManagerSwift
import CoreData
import KakaoSDKCommon // Kakao SDK 공통 모듈
import KakaoSDKAuth // 사용자 인증 및 토큰 관리 모듈
import KakaoSDKUser // 카카오 로그인 모듈
import GoogleSignIn
import AuthenticationServices
// push alarm
import Firebase
import FirebaseMessaging

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - 카카오 로그인_handleOpenURL() & 구글 로그인_인증 리디렉션 URL 처리
    // iOS 13.0 이하
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // 카카오
        if (AuthApi.isKakaoTalkLoginUrl(url)) {
            return AuthController.handleOpenUrl(url: url)
        }

        // 구글
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        
        return false
    }
    

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // MARK: - 기본 네비게이션 바 커스텀
        let appearance = UINavigationBarAppearance()
        
        // 네비게이션 바의 기본 배경을 사용하여 스타일을 구성
        appearance.configureWithDefaultBackground()
        
        // 백버튼의 글자 설정
        appearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        
        // 배경색을 투명으로 설정
        appearance.backgroundColor = UIColor.white

        // 밑줄을 없애기
        appearance.shadowColor = UIColor.clear
        
        // 기본 백버튼 이미지 및 위치 설정
        let backButtonImage = UIImage(named: "arrow_back")?.withRenderingMode(.alwaysOriginal).withAlignmentRectInsets(UIEdgeInsets(top: 0.0, left: -12.0, bottom: 0.0, right: 0.0))
        appearance.setBackIndicatorImage(backButtonImage, transitionMaskImage: backButtonImage)
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // MARK: - 키보드 관리자
        IQKeyboardManager.shared.enable = true
        IQKeyboardManager.shared.enableAutoToolbar = false
        IQKeyboardManager.shared.resignOnTouchOutside = true
        
        // MARK: - Kakao SDK 초기화
        KakaoSDK.initSDK(appKey: "7b9e4a65e4241b6e222f88eb845c4b64")
        
        // MARK: - Apple 로그인 상태 확인
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.getCredentialState(forUserID: UserDefaults.standard.string(forKey: "appleIdToken") ?? "" /* 로그인에 사용한 User Identifier */) { (credentialState, error) in
            switch credentialState {
            case .authorized:
                // The Apple ID credential is valid.
                print("해당 ID는 연동되어있습니다.")
            case .revoked:
                // The Apple ID credential is either revoked or was not found, so show the sign-in UI.
                print("해당 ID는 연동되어있지않습니다.")
            case .notFound:
                // The Apple ID credential is either was not found, so show the sign-in UI.
                print("해당 ID를 찾을 수 없습니다.")
            default:
                break
            }
        }
        
        // MARK: - 앱 실행 중 강제로 앱에 대한 Apple ID 사용이 중단 됐을 때.
        NotificationCenter.default.addObserver(forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification, object: nil, queue: nil) { (Notification) in
            print("Revoked Notification")
            // 로그인 페이지로 이동
            guard let window = (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.window else { return }
            window.rootViewController = UINavigationController(rootViewController: LoginVC()) // 전환
            UIView.transition(with: window, duration: 0.26, options: [.transitionCrossDissolve], animations: nil, completion: nil)
        }
        
        // MARK: - Firebase 설정
        FirebaseApp.configure()
        
        // 앱 실행 시 사용자에게 알림 허용 권한을 받음
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound] // 필요한 알림 권한을 설정
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions, completionHandler: { _, _ in })
        
        // UNUserNotificationCenterDelegate를 구현한 메서드를 실행시킴
        application.registerForRemoteNotifications()
        
        // 파이어베이스 Meesaging 설정
        Messaging.messaging().delegate = self
        
        // MARK: - 자동 로그인_토큰 유효성 체크
        
        Functions.checkJWTToken { token, status in
            print("토큰 유효. 웹뷰로 이동")
            
            // 토큰 활성화여부 확인시 웹뷰로 화면전환
            let url = ServiceAPI.webURL + "/?accessToken=\(token)&userStatus=\(status)"
            Functions.goToWebView(url: url)
        }
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "Sluv2")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - check notification status
    
}

// MARK: - Push Notification

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // 백그라운드에서 푸시 알림을 탭했을 때 실행
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("APNS token: \(deviceToken)")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Foreground(앱 켜진 상태)에서도 알림 오는 설정
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.list, .banner])
        } else {
            // Fallback on earlier versions
        }
    }
}

extension AppDelegate: MessagingDelegate {
    
    // 파이어베이스 MessagingDelegate 설정
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // 발급받은 fcm 토큰 unwrapping 및 String 형으로 변환
        guard let optionalNowFcmToken = fcmToken else { return }
        let nowFcmToken: String = String(describing: optionalNowFcmToken)
        
        // 이전에 저장된 fcm이 있는지 & fcm 토큰이 변화하였는지 체크
        if let prevfcm = UserDefaults.standard.string(forKey: "fcmToken") {
            // 토큰 있을 때 수행할 동작 : 기존의 토큰과 비교 후 다르면 저장 및 서버로 전송
            if prevfcm != nowFcmToken {
                setFcmToken(recentFcm: nowFcmToken)
            } else {
                // 수행할 작업 없음
            }
        } else {
            // 토큰 없을 때 수행할 동작 : 토큰 저장 및 서버로 전송
            setFcmToken(recentFcm: nowFcmToken)
        }
      
    }
    
    func setFcmToken(recentFcm: String) {
        if UserDefaults.standard.value(forKey: "token") != nil {
            let tempFcm = UserDefaults.standard.string(forKey: "fcmToken") ?? ""
            print("temp fcm !!!! \(tempFcm)")
            AuthManager.shared.checkTokenAccess(fcm: fcmModel(fcm: tempFcm)) { result in
                switch result {
                case .success(let status):
                    if status != "만료" {
                        // fcm 토큰 서버에 저장
                        AuthManager.shared.updateFcm(fcm: fcmModel(fcm: recentFcm)) { result in
                            switch result {
                            case .success(let resultMessage):
                                print("fcm 토큰 업데이트 서버 통신 성공 : \(resultMessage)")
                                // fcm 토큰 UserDefaults에 저장
                                UserDefaults.standard.set(recentFcm, forKey: "fcmToken")
                            case .failure(let error):
                                print("fcm 토큰 업데이트 서버 통신 실패 : \(error)")
                            }
                        }
                    } else {
                        print("토큰 만료. fcm 토큰 업데이트 실패.")
                    }
                default:
                    print("서버 통신 실패. fcm 토큰 업데이트 실패.")
                }
            }
        } else {
            print("저장된 토큰 없음. fcm 토큰 업데이트 실패.")
        }
        
    }
    
    // 알람 목적지 url 획득
    func getDestination(aps: [String:Any]) -> String {
        switch aps["type"] as! String {
        case "item":
            if let itemId: String = aps["itemId"] as? String {
                return "/item/detail/\(itemId)"
            } else {
                return "/home"
            }
        case "question":
                //
            if let communityId: String = aps["communityId"] as? String {
                return "/community/detail/\(communityId)"
            } else {
                return "/home"
            }
        case "user":
            if let userId: String = aps["userId"] as? String {
                return "/user/\(userId)"
            } else {
                return "/home"
            }
        case "notice":
            if let noticeId: String = aps["noticeId"] as? String {
                return "/notice/\(noticeId)"
            } else {
                return "/home"
            }
        case "comment":
            if let communityId: String = aps["communityId"] as? String,
               let _: String = aps["commentId"] as? String {
                return "/community/detail/\(communityId)"
            } else {
                return "/home"
            }
        case "report":
            if let reportId: String = aps["reportId"] as? String {
                return "/home"
                // 페이지 생성되면 url 수정
//                return "/item/detail/\(reportId)"
            } else {
                return "/home"
            }
        case "edit":
            if let itemEditId: String = aps["itemEditId"] as? String {
                return "/home"
                // 페이지 생성되면 url 수정
//                return "/item/edit/\(itemEditId)"
            } else {
                return "/home"
            }
        case "vote":
            if let communityId: String = aps["communityId"] as? String {
                return "/community/detail/\(communityId)"
            } else {
                return "/home"
            }
        case "thanks":
            if let itemEditId: String = aps["itemEditId"] as? String {
                return "/home"
                // 페이지 생성되면 url 수정
//                return "/item/edit/\(itemEditId)"
            } else {
                return "/home"
            }
        default:
            return ""
        }
    }
    
    // 알람 타입별 동작 처리
    func handleNotification(aps: [String:Any]) {
        
        Functions.checkJWTToken { token, status in
            let destinationUrl: String = ServiceAPI.webURL + self.getDestination(aps: aps)
            Functions.goToWebView(url: destinationUrl)
        } failureCompletion: {
            Functions.goToLoginVC(redirectionPath: self.getDestination(aps: aps))
        }

    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        if let aps = response.notification.request.content.userInfo as? [String:Any] {
            print(aps)
            
            // 알림 타입에 따라 처리
            handleNotification(aps: aps)
        } else {
            print("Alert 정보를 추출할 수 없습니다.")
        }

        completionHandler()
        
    }
    

}

