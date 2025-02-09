//
//  Transaction2.swift
//  SolanaSwift
//
//  Created by Chung Tran on 02/04/2021.
//

import Foundation
import TweetNacl

extension SolanaSDK {
    public struct Transaction: Encodable {
        fileprivate static let SIGNATURE_LENGTH = 64
        fileprivate static let DEFAULT_SIGNATURE = Data(repeating: 0, count: 64)
        
        public var signatures = [Signature]()
        public var feePayer: PublicKey?
        public var instructions = [TransactionInstruction]()
        public var recentBlockhash: String?
//        TODO: nonceInfo
        
        // MARK: - Methods
        public mutating func sign(signers: [Account]) throws {
            guard signers.count > 0 else { throw Error.invalidRequest(reason: "No signers") }
            
            // unique signers
            let signers = signers.reduce([Account](), { signers, signer in
                var uniqueSigners = signers
                if !uniqueSigners.contains(where: { $0.publicKey == signer.publicKey }) {
                    uniqueSigners.append(signer)
                }
                return uniqueSigners
            })
            
            // map signatures
            signatures = signers.map { Signature(signature: nil, publicKey: $0.publicKey) }
            
            // construct message
            let message = try compile()
            
            try partialSign(message: message, signers: signers)
        }
        
        public mutating func serialize(
            requiredAllSignatures: Bool = true,
            verifySignatures: Bool = false
        ) throws -> Data {
            // message
            let serializedMessage = try serializeMessage()
            
            // verification
            if verifySignatures && !_verifySignatures(serializedMessage: serializedMessage, requiredAllSignatures: requiredAllSignatures) {
                throw Error.invalidRequest(reason: "Signature verification failed")
            }
            
            return _serialize(serializedMessage: serializedMessage)
        }
        
        // MARK: - Helpers
        public mutating func addSignature(_ signature: Signature) throws {
            let _ = try compile() // Ensure signatures array is populated
            
            try _addSignature(signature)
        }
        
        mutating func serializeMessage() throws -> Data {
            try compile().serialize()
        }
        
        mutating func verifySignatures() throws -> Bool {
            _verifySignatures(serializedMessage: try serializeMessage(), requiredAllSignatures: true)
        }
        
        func findSignature(pubkey: PublicKey) -> Signature? {
            signatures.first(where: { $0.publicKey == pubkey })
        }
        
        // MARK: - Signing
        private mutating func partialSign(message: Message, signers: [Account]) throws {
            let signData = try message.serialize()
            
            for signer in signers {
                let data = try NaclSign.signDetached(message: signData, secretKey: signer.secretKey)
                try _addSignature(Signature(signature: data, publicKey: signer.publicKey))
            }
        }
        
        private mutating func _addSignature(_ signature: Signature) throws {
            guard let data = signature.signature,
                  data.count == 64,
                  let index = signatures.firstIndex(where: { $0.publicKey == signature.publicKey })
                else {
                throw Error.other("Signer not valid: \(signature.publicKey.base58EncodedString)")
            }
            
            signatures[index] = signature
        }
        
        // MARK: - Compiling
        private mutating func compile() throws -> Message {
            let message = try compileMessage()
            let signedKeys = message.accountKeys[0..<Int(message.header.numRequiredSignatures)]
            
            if signatures.count == signedKeys.count {
                var isValid = true
                for (index, signature) in signatures.enumerated() {
                    if signedKeys[index] != signature.publicKey {
                        isValid = false
                        break
                    }
                }
                if isValid {
                    return message
                }
            }
            
            signatures = signedKeys.map { Signature(signature: nil, publicKey: $0) }
            return message
        }
        
        private func compileMessage() throws -> Message {
            // verify instructions
            guard instructions.count > 0 else {
                throw Error.other("No instructions provided")
            }
            guard let feePayer = feePayer else {
                throw Error.other("Fee payer not found")
            }
            guard let recentBlockhash = recentBlockhash else {
                throw Error.other("Recent blockhash not found")
            }
            
            // programIds & accountMetas
            var programIds = [PublicKey]()
            var accountMetas = [Account.Meta]()
            
            for instruction in instructions {
                accountMetas.append(contentsOf: instruction.keys)
                if !programIds.contains(instruction.programId) {
                    programIds.append(instruction.programId)
                }
            }
            
            // Append programID account metas
            for programId in programIds {
                accountMetas.append(
                    .init(publicKey: programId, isSigner: false, isWritable: false)
                )
            }
            
            // sort accountMetas, first by signer, then by writable
            accountMetas.sort { (x, y) -> Bool in
                if x.isSigner != y.isSigner { return x.isSigner }
                if x.isWritable != y.isWritable { return x.isWritable }
                return false
            }
            
            // filterOut duplicate account metas, keeps writable one
            accountMetas = accountMetas.reduce([Account.Meta](), { result, accountMeta in
                var uniqueMetas = result
                if let index = uniqueMetas.firstIndex(where: { $0.publicKey == accountMeta.publicKey }) {
                    // if accountMeta exists
                    uniqueMetas[index].isWritable = uniqueMetas[index].isWritable || accountMeta.isWritable
                } else {
                    uniqueMetas.append(accountMeta)
                }
                return uniqueMetas
            })
            
            // Cull duplicate account metas
            var uniqueMetas: [SolanaSDK.Account.Meta] = []
            accountMetas.forEach { accountMeta in
                let pubkey = accountMeta.publicKey.base58EncodedString
                let uniqueIndex = uniqueMetas.index { x in x.publicKey.base58EncodedString == pubkey }
                if let uniqueIndex = uniqueIndex {
                    uniqueMetas[uniqueIndex].isWritable = uniqueMetas[uniqueIndex].isWritable || accountMeta.isWritable
                } else {
                    uniqueMetas.append(accountMeta)
                }
            }
            
            // move fee payer to front
            let feePayerIndex = uniqueMetas.index { x in x.publicKey == feePayer }
            if let feePayerIndex = feePayerIndex {
                var payerMeta = uniqueMetas.remove(at: feePayerIndex)
                payerMeta.isSigner = true;
                payerMeta.isWritable = true;
                uniqueMetas.insert(payerMeta, at: 0)
            } else {
                uniqueMetas.insert(
                    SolanaSDK.Account.Meta(
                        publicKey: feePayer,
                        isSigner: true,
                        isWritable: true),
                    at: 0)
            }
            
            //accountMetas.removeAll(where: { $0.publicKey == feePayer })
            //accountMetas.insert(
            //    Account.Meta(publicKey: feePayer, isSigner: true, isWritable: true),
            //    at: 0
            //)
            
            // verify signers
            for signature in signatures {
                if let index = try? uniqueMetas.index(ofElementWithPublicKey: signature.publicKey) {
                    if !uniqueMetas[index].isSigner {
                        // TODO: check
                        uniqueMetas[index].isSigner = true;
//                        accountMetas[index].isSigner = true
//                        Logger.log(message: "Transaction references a signature that is unnecessary, only the fee payer and instruction signer accounts should sign a transaction. This behavior is deprecated and will throw an error in the next major version release.", event: .warning)
                        print("WARN: Transaction references a signature that is unnecessary")
//                        throw Error.invalidRequest(reason: "Transaction references a signature that is unnecessary")
                    }
                } else {
                    throw Error.invalidRequest(reason: "Unknown signer: \(signature.publicKey.base58EncodedString)")
                }
            }
            
            // header
            var header = Message.Header()
            
            var signedKeys = [Account.Meta]()
            var unsignedKeys = [Account.Meta]()
            
            uniqueMetas.forEach { accountMeta in
                // signed keys
                if accountMeta.isSigner {
                    signedKeys.append(accountMeta)
                    header.numRequiredSignatures += 1
                    
                    if !accountMeta.isWritable {
                        header.numReadonlySignedAccounts += 1
                    }
                }
                
                // unsigned keys
                else {
                    unsignedKeys.append(accountMeta)
                    
                    if !accountMeta.isWritable {
                        header.numReadonlyUnsignedAccounts += 1
                    }
                }
            }
            
            accountMetas = signedKeys + unsignedKeys
            let accountKeys = accountMetas.map { $0.publicKey }
            let instructions = instructions.compile(accountKeys: accountKeys)
            try instructions.forEach { instruction in
                if instruction.programIdIndex < 0 { throw Error.assertionFailed }
                try instruction.accounts.forEach { keyIndex in
                    if (keyIndex < 0) { throw Error.assertionFailed }
                }
            }
            
            return Message(
                header: header,
                accountKeys: accountKeys,
                recentBlockhash: recentBlockhash,
                instructions: instructions
            )
        }
        
        // MARK: - Verifying
        private mutating func _verifySignatures(
            serializedMessage: Data,
            requiredAllSignatures: Bool
        ) -> Bool {
            for signature in signatures {
                if signature.signature == nil {
                    if requiredAllSignatures {
                        return false
                    }
                } else {
                    if (try? NaclSign.signDetachedVerify(message: serializedMessage, sig: signature.signature!, publicKey: signature.publicKey.data)) != true {
                        return false
                    }
                }
            }
            return true
        }
        
        // MARK: - Serializing
        private mutating func _serialize(serializedMessage: Data) -> Data {
            // signature length
            let signaturesLength = signatures.count
            
            // signature data
            let signaturesData = signatures.reduce(Data(), { result, signature in
                var data = result
                if let signature = signature.signature {
                    data.append(signature)
                } else {
                    data.append(SolanaSDK.Transaction.DEFAULT_SIGNATURE)
                }
                return data
            })
            
            let encodedSignatureLength = Data.encodeLength(signaturesLength)
            
            // transaction length
            var data = Data(capacity: encodedSignatureLength.count + signaturesData.count + serializedMessage.count)
            data.append(encodedSignatureLength)
            data.append(signaturesData)
            data.append(serializedMessage)
            return data
        }
        
        static public func from(data: Data) throws -> Transaction {
            var data = data
            var signatures: [String] = []
            let signatureCount = try data.decodeLength()
            
            for index in stride(from: 0, through: signatureCount - 1, by: 1) {
                let signatureData = data.prefix(Transaction.SIGNATURE_LENGTH)
                data = data.dropFirst(Transaction.SIGNATURE_LENGTH)
                signatures.append(Base58.encode(signatureData))
            }
    
            print(data.base64EncodedString())
            return populate(try Transaction.Message.from(data: data), signatures)
        }
        
        static func populate(_ message: Transaction.Message, _ signatures: [String]) -> Transaction {
            var transaction = Transaction()
            
            transaction.recentBlockhash = message.recentBlockhash
            if (message.header.numRequiredSignatures > 0) {
                transaction.feePayer = message.accountKeys[0]
            }
            signatures.enumerated().forEach { (index, signature) in
                let sigPubkeyPair = SolanaSDK.Transaction.Signature(
                    signature: signature == Base58.encode(SolanaSDK.Transaction.DEFAULT_SIGNATURE) ? nil : Data(bytes: Base58.decode(signature)),
                    publicKey: message.accountKeys[index]
                )
                transaction.signatures.append(sigPubkeyPair)
            }
            
            message.instructions.forEach { instruction in
                let keys: [SolanaSDK.Account.Meta] = instruction.accounts.map { account in
                    let pubkey = message.accountKeys[account]
                    return SolanaSDK.Account.Meta(
                        publicKey: pubkey,
                        isSigner: transaction.signatures.contains { keyObj in keyObj.publicKey == pubkey } || message.isAccountSigner(index: account),
                        isWritable: message.isAccountWritable(index: account)
                    )
                }
                
                transaction.instructions.append(
                    TransactionInstruction(keys: keys, programId: message.accountKeys[instruction.programIdIndexValue], data: instruction.data)
                )
            }
            
            return transaction
        }
    }
}

extension SolanaSDK.Transaction {
    public struct Signature: Encodable {
        public var signature: Data?
        public var publicKey: SolanaSDK.PublicKey
        
        enum CodingKeys: String, CodingKey {
            case signature, publicKey
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Base58.encode((signature?.bytes ?? [])), forKey: .signature)
            try container.encode(publicKey.base58EncodedString, forKey: .publicKey)
        }
    }
}
