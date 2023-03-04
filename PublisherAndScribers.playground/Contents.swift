import Foundation
import Combine
import _Concurrency

var subscriptions = Set<AnyCancellable>()


//使用async/await异步方式获取publisher中的数据 2023-03-03(周五) 08:26:32
example(of: "async/await") {
    let subject = CurrentValueSubject<Int, Never>(0)
    
    Task {
        for await value in subject.values {
            print("Received value in await: \(value)")
        }
        print("Task is completed")
    }
    
    subject.send(1)
    subject.send(2)
    subject.send(3)
    subject.send(completion: .finished)
}

/*
 ——— Example of: async/await ———
 Received value in await: 0
 Received value in await: 1
 Received value in await: 2
 Received value in await: 3
 Task is completed
 */

//隐藏subject的细节，向下游屏蔽,使用eraseToAnyPublisher() 2023-03-02(周四) 05:56:53
example(of: "Type rerase") {
    let subject = PassthroughSubject<Int, Never>()
    let publisher = subject.eraseToAnyPublisher()
    publisher
        .sink { value in
            print("received value in sink: \(value)")
        }
        .store(in: &subscriptions)
    
    subject.send(0)
    //publisher不能访问到真正的subject的属性与方法的内容
//    publisher.send(1)
}

/*
 
 ——— Example of: Type rerase ———
 received value in sink: 0
 
 */

//可以调整subscriber接收消息的数量，并可以在接收消息过程中动态的调整 2023-03-02(周四) 05:43:56
example(of: "Dynamically ajusting Demand") {
    final class IntSubscriber: Subscriber {
      
        typealias Input = Int
        typealias Failure = Never
        
        func receive(subscription: Subscription) {
            subscription.request(.max(2))
        }
        
        func receive(_ input: Int) -> Subscribers.Demand {
            print("Received value in subscriber: \(input)")
            switch input {
            case 1:
                return .max(3)
            case 2:
                return .max(2)
            case 3:
                return .max(1)
            default:
                return .none
            }
        }
        
        func receive(completion: Subscribers.Completion<Never>) {
            print("Received completion in subscriber: \(completion)")
        }
    }
    
    let subscriber = IntSubscriber()
    
    let subject = PassthroughSubject<Int, Never>()
    
    subject.subscribe(subscriber)
    
    subject.send(1)
    subject.send(2)
    subject.send(3)
    subject.send(4)
    subject.send(5)
    subject.send(6)
    subject.send(7)
    subject.send(8)
    subject.send(9)
    subject.send(10)
    subject.send(11)
}

/*
 ——— Example of: Dynamically ajusting Demand ———
 Received value in subscriber: 1
 Received value in subscriber: 2
 Received value in subscriber: 3
 Received value in subscriber: 4
 Received value in subscriber: 5
 Received value in subscriber: 6
 Received value in subscriber: 7
 Received value in subscriber: 8
 */

//创建一个带初始值的publisher，可以随时赋值，并且发送消息 2023-03-01(周三) 20:47:51
example(of: "CurrentValueSubject") {
    var subscriptions = Set<AnyCancellable>()
    let subject = CurrentValueSubject<Int, Never>(0)
    subject
        .print()
        .sink { value in
            print("Received in sink: \(value)")
        }
        .store(in: &subscriptions)
    subject.send(1)
    subject.send(2)
    print("current value: \(subject.value)")
    subject.value = 3
    print("current value: \(subject.value)")
    subject
        .print()
        .sink { value in
            print("Received again in sink: \(value)")
        }
        .store(in: &subscriptions)
    subject.send(completion: .finished)
    
}

/*
 
 ——— Example of: CurrentValueSubject ———
 receive subscription: (CurrentValueSubject)
 request unlimited
 receive value: (0)
 Received in sink: 0
 receive value: (1)
 Received in sink: 1
 receive value: (2)
 Received in sink: 2
 current value: 2
 receive value: (3)
 Received in sink: 3
 current value: 3
 receive subscription: (CurrentValueSubject)
 request unlimited
 receive value: (3)
 Received again in sink: 3
 receive finished
 receive finished
 */

//创建一个信息直通型的publisher来send数据，可以用自定义的subscriber来获取数据，也可以用sink 2023-03-01(周三) 20:25:00
example(of: "PassthroughSubject") {
    enum MyError: Error {
        case test
    }
    
    final class StringSubsriber: Subscriber {
        
        typealias Input = String
        typealias Failure = MyError
        
        func receive(subscription: Subscription) {
            subscription.request(.max(2))
        }
        
        func receive(_ input: String) -> Subscribers.Demand {
            print("Received value in stringSubscriber: \(input)")
            return input == "World" ? .max(1) : .none
        }
        
        func receive(completion: Subscribers.Completion<MyError>) {
            print("Received Completed in stringSubscriber: \(completion)")
        }
    }
    
    let subscriber = StringSubsriber()
    
    let subject = PassthroughSubject<String, MyError>()
    
    subject.subscribe(subscriber)
    
    let subscription = subject
        .sink { completion in
            print("Received completion in sink: \(completion)")
        } receiveValue: { value in
            print("Received value in sink: \(value)")
        }

    subject.send("hello")
    subject.send("World")
    
    subscription.cancel()
    subject.send("third message, not received by sink")
    
    subject.send(completion: .failure(.test))
    subject.send(completion: .finished)
    
    subject.send("fourth message")
    
}
/*
 ——— Example of: PassthroughSubject ———
 Received value in stringSubscriber: hello
 Received value in sink: hello
 Received value in stringSubscriber: World
 Received value in sink: World
 Received value in stringSubscriber: third message, not received by sink
 Received Completed in stringSubscriber: failure(__lldb_expr_13.(unknown context at $10a486144).(unknown context at $10a48614c).(unknown context at $10a486154).MyError.test)
 
 */

//可以自己创建自定义的pulisher，例如future：发送一次消息给下游 2023-03-01(周三) 06:38:29
example(of: "future") {
    func futureIncrement(integer: Int, afterDelay delay: TimeInterval) -> Future<Int, Never> {
        Future<Int,Never> { promise in
            print("Before timer")
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                promise(.success(integer + 1))
            }
        }
    }
    
    let future = futureIncrement(integer: 1, afterDelay: 3)
    
    future
        .sink { result in
            print("result: \(result)")
        } receiveValue: { value in
            print("value: \(value)")
        }
        .store(in: &subscriptions)
    //重复发送结果给第二个下游
    future
        .sink { result in
            print("second result: \(result)")
        } receiveValue: { value in
            print("second value: \(value)")
        }
        .store(in: &subscriptions)
}

/*
 ——— Example of: future ———
 Before timer
 value: 2
 result: finished
 second value: 2
 second result: finished
 
 */

//数据的发送实际上是subscriber写的，用来给pubulisher调用，从而把数据传过去 2023-03-01(周三) 05:49:00
example(of: "Custom Subscriber") {
    let publisher = (1...6).publisher
    ///不能是其他类型的pulisher
//    let publisher = ["a","b","c","d","e","f"].publisher
    final class IntSubscriber: Subscriber {
        typealias Input = Int
        
        typealias Failure = Never
        ///告诉publisher最多需要多少数据
        func receive(subscription: Subscription) {
            subscription.request(.max(3))
        }
        ///实时调整数据量的值，避免数据处理压力
        func receive(_ input: Int) -> Subscribers.Demand {
            print("Received value: \(input)")
//            return .none
//            return .unlimited
            return .max(1)
        }
        ///
        func receive(completion: Subscribers.Completion<Never>) {
            print("Received completion: \(completion)")
        }
    }
    
    let subscriber = IntSubscriber()
    publisher.subscribe(subscriber)
    
}

//使用“ @Published ”来创建能发送消息的property 2023-02-28(周二) 08:33:18
//用第三方来更新class的property publisher，避免强引用造成的存储泄露(另一个办法是用unowned self) 2023-03-01(周三) 06:07:04
//publisher是Protocol，属性可以实现它 2023-02-28(周二) 19:25:37
example(of: "assign(to:)") {
    class SomeObject {
        @Published var value = 0
    }
    let object = SomeObject()
    
    object.$value
        .sink { value in
            print("SomeOject.value is set: \(value)")
        }
    
    (0..<10).publisher
        .assign(to: &object.$value)
    
}

//使用assign(to:on:)对某个对象的属性进行赋值 2023-02-28(周二) 08:18:16
example(of: "assign(to:on:)") {
    class SomeObject {
        var value: String = "" {
            didSet {
                print("SomeOject.value: \(value)")
            }
        }
    }
    
    let object = SomeObject()
    
    let publisher = ["hello","world"].publisher
    
    _ = publisher
        .assign(to: \.value, on: object)
}

//使用just构建一个简单的publisher，使用sink的completion和receivevalue机制 2023-02-28(周二) 08:10:10
example(of: "Just") {
    let just = Just("Just Hushouwen")
    
    _ = just
        .sink(receiveCompletion: { value in
            print("Just pipeline complete: \(value)")
        }, receiveValue: { value in
            print("Just pipeline value: \(value)")
        })
    
}

//使用notification的publisher获取异步消息数据 2023-02-28(周二) 07:46:20
example(of: "Subscriber") {
    let myNotification = Notification.Name("MyNotification")
    let center = NotificationCenter.default
    let publisher = center.publisher(for: myNotification, object: nil)
    
    let subscription = publisher
        .sink { notification in
            print("received from subscriber!")
            print("message is: \(notification.object as! String)")
        }
    center.post(name: myNotification, object: "hushouwen")
    
    subscription.cancel()
}

//传统的notifcation center获取消息的方法 2023-02-28(周二) 07:44:34
example(of: "Publisher") {
    let myNotification = Notification.Name("MyNotifiy")
//    let publisher = NotificationCenter.default.publisher(for: myNotification, object: nil)
    let center = NotificationCenter.default

    let observer = center.addObserver(forName: myNotification, object: nil, queue: nil) { notification in
        print("Notification received!")
        print("Message is \(notification.object as! String)")
    }
    center.post(name: myNotification, object: "hushouwen")
    center.removeObserver(observer)
}





/// Copyright (c) 2021 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.
