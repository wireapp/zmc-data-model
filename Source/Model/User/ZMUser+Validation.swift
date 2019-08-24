//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation

public extension ZMUser {
    
    // Name
    
    static func validate(name: inout String?) throws -> Bool {
        
        var mutableName: Any? = name
        
        do {
            _ = try ExtremeCombiningCharactersValidator.validateValue(&mutableName)
        } catch {
            return false
        }
        
        var validate = false
        
        do {
            // The backend limits to 128. We'll fly just a bit below the radar.
            validate = try StringLengthValidator.validateValue(&mutableName, minimumStringLength: 2, maximumStringLength: 100, maximumByteLength: UInt32.max)
        } catch {
            return false
        }
        
        name = mutableName as? String
        
        return name == nil || validate
    }
    
    @objc(isValidName:)
    static func isValid(name: String?) -> Bool {
        var name = name
        return (try? validate(name: &name)) == true
    }
    
    // Accent color
    
    static func validate(accentColor: inout Int?) throws -> Bool {
        var mutableAccentColor: Any? = accentColor
        do {
            let result = try ZMAccentColorValidator.validateValue(&mutableAccentColor)
            accentColor = mutableAccentColor as? Int
            return result
        } catch let error {
            throw error
        }
    }
    
    // E-mail address
    
    static func validate(emailAddress: inout String?) throws -> Bool {
        var mutableEmailAddress: Any? = emailAddress
        do {
            let result = try ZMEmailAddressValidator.validateValue(&mutableEmailAddress)
            emailAddress = mutableEmailAddress as? String
            return result
        } catch let error {
            throw error
        }
    }

    @objc(isValidEmailAddress:)
    static func isValid(emailAddress: String?) -> Bool {
        var emailAddress = emailAddress
        return (try? validate(emailAddress: &emailAddress)) == true
    }
    
    // Password
    
    static func validate(password: inout String?) throws -> Bool {
        var mutablePassword: Any? = password
        do {
            let result = try StringLengthValidator.validateValue(&mutablePassword,
                                                                 minimumStringLength: 8,
                                                                 maximumStringLength: 120,
                                                                 maximumByteLength: UInt32.max)
            password = mutablePassword as? String
            return result
        } catch let error {
            throw error
        }
    }
    
    @objc(isValidPassword:)
    static func isValid(password: String?) -> Bool {
        var password = password
        return (try? validate(password: &password)) == true
    }
    
    // Phone number
    
    static func validate(phoneNumber: inout String?) throws -> Bool {
        guard var mutableNumber = phoneNumber as? Any?,
            phoneNumber?.count ?? 0 >= 1 else {
                return false
        }
        
        do {
            let result = try ZMPhoneNumberValidator.validateValue(&mutableNumber)
            phoneNumber = mutableNumber as? String
            return result
        } catch let error {
            throw error
        }
    }
    
    @objc(isValidPhoneNumber:)
    static func isValid(phoneNumber: String?) -> Bool {
        var phoneNumber = phoneNumber
        return (try? validate(phoneNumber: &phoneNumber)) == true
    }
    
    // Verification code
    
    static func validate(phoneVerificationCode: inout String?) throws -> Bool {
        var mutableCode: Any? = phoneVerificationCode
        do {
            let result = try StringLengthValidator.validateValue(&mutableCode, minimumStringLength: 6, maximumStringLength: 6, maximumByteLength: UInt32.max)
            phoneVerificationCode = mutableCode as? String
            return result
        } catch let error {
            throw error
        }
    }
    
    @objc(isValidPhoneVerificationCode:)
    static func isValid(phoneVerificationCode: String?) -> Bool {
        var verificationCode = phoneVerificationCode
        let result = (try? validate(phoneVerificationCode: &verificationCode))
        return result == true
    }
}
