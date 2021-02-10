//
//  ARReplayTest.swift
//  3D Ultrasonic ScannerTests
//
//  Created by Po-Wen on 2021/2/10.
//

import XCTest
@testable import UltrasoundScanner
class ARReplayTest: XCTestCase {
    let recorder = ARRecorder()
    let player = ARPlayer()
    // test input
    let baseUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    let inputA = matrix_float4x4([0, 1, 2, 3],
                                 [4, 5, 6, 7],
                                 [8, 9 ,10 ,11],
                                 [12, 13, 14, 15])
    let inputB = matrix_float4x4([0, 66, 2, 3],
                                 [4, 5, 6, 7],
                                 [8, 9 ,10 ,11],
                                 [12, 13, 14, 55])
    
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        
      
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDataWriteAndRead() {
        let url = URL(fileURLWithPath: "testCase.file", relativeTo: baseUrl)
        
        let inputs = [inputA, inputB]
        
        for (i, _input) in inputs.enumerated(){
            let timestamp: TimeInterval = TimeInterval(5566 + i)

            recorder.open(file: url, size: nil)
            recorder.append(frame: ARFrameModel(transform: _input, timestamp: timestamp))
            recorder.save(completeHandler: {[self] _,_ in
                player.read(file: url)
                XCTAssertEqual(player.buffer![0].transform, _input)
                XCTAssertEqual(player.buffer![0].timestamp, timestamp)
            })
            recorder.close()
        }

        
        
    }
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
