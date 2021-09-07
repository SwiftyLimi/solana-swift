//
//  DecodingConfirmedTransactionTests.swift
//  SolanaSwift_Tests
//
//  Created by Chung Tran on 05/04/2021.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import XCTest
@testable import SolanaSwift

class DecodingConfirmedTransactionTests: XCTestCase {
    let endpoint = SolanaSDK.APIEndPoint(
        url: "https://api.mainnet-beta.solana.com",
        network: .mainnetBeta
    )
    var solanaSDK: SolanaSDK!
    var parser: SolanaSDK.TransactionParser!
    
    override func setUpWithError() throws {
        let accountStorage = InMemoryAccountStorage()
        solanaSDK = SolanaSDK(endpoint: endpoint, accountStorage: accountStorage)
        
        let account = try SolanaSDK.Account(phrase: endpoint.network.testAccount.components(separatedBy: " "), network: endpoint.network)
        
        try accountStorage.save(account)
        
        parser = SolanaSDK.TransactionParser(solanaSDK: solanaSDK)
    }
    
    func testDecodingCreateAccountTransaction() throws {
        let transaction = try parse(fileName: "CreateAccountTransaction").value as! SolanaSDK.CreateAccountTransaction
        
        XCTAssertEqual(transaction.fee, 0.00203928)
        XCTAssertEqual(transaction.newWallet?.token.symbol, "ETH")
        XCTAssertEqual(transaction.newWallet?.pubkey, "8jpWBKSoU7SXz9gJPJS53TEXXuWcg1frXLEdnfomxLwZ")
    }
    
    func testDecodingCloseAccountTransaction() throws {
        let transaction = try parse(fileName: "CloseAccountTransaction").value as! SolanaSDK.CloseAccountTransaction
        
        XCTAssertEqual(transaction.reimbursedAmount, 0.00203928)
        XCTAssertEqual(transaction.closedWallet?.token.symbol, "ETH")
    }
    
    func testDecodingSendSOLTransaction() throws {
        let myAccount = "6QuXb6mB6WmRASP2y8AavXh6aabBXEH5ZzrSH5xRrgSm"
        let transaction = try parse(fileName: "SendSOLTransaction", myAccount: myAccount).value as! SolanaSDK.TransferTransaction
        
        XCTAssertEqual(transaction.source?.token.symbol, "SOL")
        XCTAssertEqual(transaction.source?.pubkey, myAccount)
        XCTAssertEqual(transaction.destination?.pubkey, "3h1zGmCwsRJnVk5BuRNMLsPaQu1y2aqXqXDWYCgrp5UG")
        XCTAssertEqual(transaction.authority, nil)
        XCTAssertEqual(transaction.destinationAuthority, nil)
        XCTAssertEqual(transaction.amount, 0.01)
        XCTAssertEqual(transaction.wasPaidByP2POrg, false)
    }
    
    func testDecodingSendSOLTransactionPaidByP2PORG() throws {
        let myAccount = "6QuXb6mB6WmRASP2y8AavXh6aabBXEH5ZzrSH5xRrgSm"
        let transaction = try parse(fileName: "SendSOLTransactionPaidByP2PORG", myAccount: myAccount).value as! SolanaSDK.TransferTransaction
        
        XCTAssertEqual(transaction.source?.token.symbol, "SOL")
        XCTAssertEqual(transaction.source?.pubkey, myAccount)
        XCTAssertEqual(transaction.destination?.pubkey, "3h1zGmCwsRJnVk5BuRNMLsPaQu1y2aqXqXDWYCgrp5UG")
        XCTAssertEqual(transaction.authority, nil)
        XCTAssertEqual(transaction.destinationAuthority, nil)
        XCTAssertEqual(transaction.amount, 0.00001)
        XCTAssertEqual(transaction.wasPaidByP2POrg, true)
    }
    
    func testDecodingSendSPLToSOLTransaction() throws {
        let myAccount = "22hXC9c4SGccwCkjtJwZ2VGRfhDYh9KSRCviD8bs4Xbg"
        let transaction = try parse(fileName: "SendSPLToSOLTransaction", myAccount: myAccount).value as! SolanaSDK.TransferTransaction
        
        XCTAssertEqual(transaction.source?.token.symbol, "wUSDT")
        XCTAssertEqual(transaction.source?.pubkey, myAccount)
        XCTAssertEqual(transaction.destination?.pubkey, "GCmbXJRc6mfnNNbnh5ja2TwWFzVzBp8MovsrTciw1HeS")
        XCTAssertEqual(transaction.authority, "6QuXb6mB6WmRASP2y8AavXh6aabBXEH5ZzrSH5xRrgSm")
        XCTAssertEqual(transaction.destinationAuthority, "3h1zGmCwsRJnVk5BuRNMLsPaQu1y2aqXqXDWYCgrp5UG")
        XCTAssertEqual(transaction.amount, 0.004325)
    }
    
    func testDecodingSendSPLToSPLTransaction() throws {
        let myAccount = "BjUEdE292SLEq9mMeKtY3GXL6wirn7DqJPhrukCqAUua"
        let transaction = try parse(fileName: "SendSPLToSPLTransaction", myAccount: myAccount).value as! SolanaSDK.TransferTransaction
        
        XCTAssertEqual(transaction.source?.token.symbol, "SRM")
        XCTAssertEqual(transaction.source?.pubkey, myAccount)
        XCTAssertEqual(transaction.destination?.pubkey, "3YuhjsaohzpzEYAsonBQakYDj3VFWimhDn7bci8ERKTh")
        XCTAssertEqual(transaction.authority, "3h1zGmCwsRJnVk5BuRNMLsPaQu1y2aqXqXDWYCgrp5UG")
        XCTAssertEqual(transaction.destinationAuthority, "6QuXb6mB6WmRASP2y8AavXh6aabBXEH5ZzrSH5xRrgSm")
        XCTAssertEqual(transaction.amount, 0.012111)
    }
    
    func testDecodingSendTokenToNewAssociatedTokenAddress() throws {
        let myAccount = "H1yu3R247X5jQN9bbDU8KB7RY4JSeEaCv45p5CMziefd"
        let transaction = try parse(fileName: "SendTokenToNewAssociatedTokenAddress", myAccount: myAccount, myAccountSymbol: "MAPS").value as! SolanaSDK.TransferTransaction
        
        XCTAssertEqual(transaction.source?.token.symbol, "MAPS")
        XCTAssertEqual(transaction.source?.pubkey, myAccount)
        XCTAssertEqual(transaction.amount, 0.001)
        XCTAssertEqual(transaction.authority, "6QuXb6mB6WmRASP2y8AavXh6aabBXEH5ZzrSH5xRrgSm")
        XCTAssertEqual(transaction.destinationAuthority, "3h1zGmCwsRJnVk5BuRNMLsPaQu1y2aqXqXDWYCgrp5UG")
        
        // transfer checked type
        let transaction2 = try parse(fileName: "SendTokenToNewAssociatedTokenAddressTransferChecked", myAccount: myAccount, myAccountSymbol: "MAPS").value as! SolanaSDK.TransferTransaction
        
        XCTAssertEqual(transaction2.source?.token.symbol, "MAPS")
        XCTAssertEqual(transaction2.source?.pubkey, myAccount)
        XCTAssertEqual(transaction2.amount, 0.001)
        XCTAssertEqual(transaction.authority, "6QuXb6mB6WmRASP2y8AavXh6aabBXEH5ZzrSH5xRrgSm")
        XCTAssertEqual(transaction.destinationAuthority, "3h1zGmCwsRJnVk5BuRNMLsPaQu1y2aqXqXDWYCgrp5UG")
    }
    
    func testDecodingSendSPLTokenParsedInNativeSOLWallet() throws {
        let myAccount = "3h1zGmCwsRJnVk5BuRNMLsPaQu1y2aqXqXDWYCgrp5UG"
        let transaction = try parse(fileName: "SendSPLTokenParsedInNativeSOLWallet", myAccount: myAccount).value as! SolanaSDK.TransferTransaction
        
        XCTAssertEqual(transaction.source?.token.symbol, "RAY")
        XCTAssertEqual(transaction.authority, myAccount)
        XCTAssertEqual(transaction.source?.pubkey, "5ADqZHdZzL3xd2NiP8MrM4pCFj5ijC4oQWSBzvXx4fbY")
        XCTAssertEqual(transaction.destination?.pubkey, "4ijqHixcbzhxQbfJWAoPkvBhokBDRGtXyqVcMN8ywj8W")
        XCTAssertEqual(transaction.authority, "3h1zGmCwsRJnVk5BuRNMLsPaQu1y2aqXqXDWYCgrp5UG")
        XCTAssertEqual(transaction.destinationAuthority, "B4PdyoVU39hoCaiTLPtN9nJxy6rEpbciE3BNPvHkCeE2")
        XCTAssertEqual(transaction.transferType, .send)
        XCTAssertEqual(transaction.wasPaidByP2POrg, true)
    }
    
    func testDecodingProvideLiquidityToPoolTransaction() throws {
        let myAccount = "H1yu3R247X5jQN9bbDU8KB7RY4JSeEaCv45p5CMziefd"
        let transaction = try parse(fileName: "ProvideLiquidityToPoolTransaction", myAccount: myAccount)
        
        XCTAssertNil(transaction.value)
    }
    
    func testDecodingBurnLiquidityInPoolTransaction() throws {
        let myAccount = "H1yu3R247X5jQN9bbDU8KB7RY4JSeEaCv45p5CMziefd"
        let transaction = try parse(fileName: "BurnLiquidityInPoolTransaction", myAccount: myAccount)
        
        XCTAssertNil(transaction.value)
    }
    
    func testDecodingSwapTransaction() throws {
        let myAccountSymbol = "SOL"
        let transaction = try parse(fileName: "SwapTransaction", myAccountSymbol: myAccountSymbol).value as! SolanaSDK.SwapTransaction
        
        XCTAssertEqual(transaction.source?.token.symbol, "SRM")
        XCTAssertEqual(transaction.source?.pubkey, "BjUEdE292SLEq9mMeKtY3GXL6wirn7DqJPhrukCqAUua")
        XCTAssertEqual(transaction.sourceAmount, 0.001)
        
        XCTAssertEqual(transaction.destination?.token.symbol, myAccountSymbol)
        XCTAssertEqual(transaction.destinationAmount, 0.000364885)
    }
    
    func testDecodingSwapErrorTransaction() throws {
        let myAccount = "G8PrkEwmVx3kt3rXBin5o1bdDC1cvz7oBnXbHksNg7R4"
        let parsedTransaction = try parse(fileName: "SwapErrorTransaction", myAccount: myAccount)
        let transaction = parsedTransaction.value as! SolanaSDK.SwapTransaction
        
        XCTAssertEqual(parsedTransaction.status, .error("Swap instruction exceeds desired slippage limit"))
        XCTAssertEqual(transaction.source?.token.symbol, "KIN")
        XCTAssertEqual(transaction.source?.pubkey, "2xKofw1wK2CVMVUssGTv3G5pVrUALAR9r8J9zZnwtrUG")
        XCTAssertEqual(transaction.sourceAmount?.rounded(), 100)
        
        XCTAssertEqual(transaction.destination?.token.symbol, "SOL")
        XCTAssertEqual(transaction.destination?.pubkey, "G8PrkEwmVx3kt3rXBin5o1bdDC1cvz7oBnXbHksNg7R4")
    }
    
    func testDecodingSerumSwapTransaction() throws {
        let parsedTransaction = try parse(
            fileName: "SerumSwapTransaction",
            myWallets: [
                .init(
                    pubkey: "375DTPnEBUjCnvQpGQtg5nRQudwa6oXWEYB15X6MmJs6",
                    lamports: 0,
                    token: .init(
                        _tags: nil,
                        chainId: 101,
                        address: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
                        symbol: "USDC",
                        name: "USDC",
                        decimals: 6,
                        logoURI: nil,
                        extensions: nil
                    )
                )
            ]
        )
        let transaction = parsedTransaction.value as! SolanaSDK.SwapTransaction
        
        XCTAssertEqual(transaction.source?.token.symbol, "SOL")
//        XCTAssertEqual(transaction.source?.pubkey, "D7XYERWodEGaoN2X855T2qLvse28BSjfkvfCyW2EDBWy")
        XCTAssertEqual(transaction.sourceAmount, 0.1)
        
        XCTAssertEqual(transaction.destination?.token.symbol, "USDC")
        XCTAssertEqual(transaction.destinationAmount?.toLamport(decimals: 6), 14198095)
    }
    
    func testDecodingSerumSwapTransaction2() throws {
        let parsedTransaction = try parse(
            fileName: "SerumSwapTransaction2",
            myWallets: [
                .init(
                    pubkey: "FT3A24vCezU25TzvDfPmDdHwpHDQdYZU4Z6Lt3Kf8WsT",
                    lamports: 0,
                    token: .init(
                        _tags: nil,
                        chainId: 101,
                        address: "2FPyTwcZLUg1MDrwsyoP4D6s1tM7hAkHYRjkNb5w6Pxk",
                        symbol: "ETH",
                        name: "Etherum",
                        decimals: 6,
                        logoURI: nil,
                        extensions: nil
                    )
                )
            ]
        )
        let transaction = parsedTransaction.value as! SolanaSDK.SwapTransaction
        
        XCTAssertEqual(transaction.source?.token.symbol, "BTC")
//        XCTAssertEqual(transaction.source?.pubkey, "D7XYERWodEGaoN2X855T2qLvse28BSjfkvfCyW2EDBWy")
        XCTAssertEqual(transaction.sourceAmount, 0.001)
        
        XCTAssertEqual(transaction.destination?.token.symbol, "ETH")
        XCTAssertEqual(transaction.destinationAmount?.toLamport(decimals: transaction.destination?.token.decimals ?? 0), 13000)
    }
    
    private func parse(
        fileName: String,
        myAccount: String? = nil,
        myAccountSymbol: String? = nil,
        myWallets: [SolanaSDK.Wallet] = []
    ) throws -> SolanaSDK.ParsedTransaction {
        let transactionInfo = try transactionInfoFromJSONFileName(fileName)
        return try parser.parse(transactionInfo: transactionInfo, myAccount: myAccount, myAccountSymbol: myAccountSymbol, p2pFeePayerPubkeys: ["FG4Y3yX4AAchp1HvNZ7LfzFTewF2f6nDoMDCohTFrdpT"], myWallets: myWallets)
            .toBlocking().first()!
    }
    
    private func transactionInfoFromJSONFileName(_ name: String) throws -> SolanaSDK.TransactionInfo
    {
        let path = Bundle(for: Self.self).path(forResource: name, ofType: "json")
        let data = try Data(contentsOf: .init(fileURLWithPath: path!))
        let transactionInfo = try JSONDecoder().decode(SolanaSDK.TransactionInfo.self, from: data)
        return transactionInfo
    }
}
