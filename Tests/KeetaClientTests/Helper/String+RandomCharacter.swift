extension String {
    static func randomLetter(lowercased: Bool = true) -> Character {
        let letters = lowercased ? "abcdefghijklmnopqrstuvwxyz" : "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return letters.randomElement()!
    }
}
