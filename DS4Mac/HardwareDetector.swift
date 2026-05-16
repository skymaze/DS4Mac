import Darwin

enum HardwareDetector {
    static var supportsSME: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm.FEAT_SME", &value, &size, nil, 0)
        return result == 0 && value == 1
    }
}
