import WidgetKit

struct Provider: TimelineProvider {

    // آيات تجريبية (ديناميكية بسيطة)
    private let sampleAyat: [Ayah] = [
        Ayah(text: "إِنَّ مَعَ الْعُسْرِ يُسْرًا", surahName: "الشرح", surahNumber: 94, ayahNumber: 6),
        Ayah(text: "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ", surahName: "الرعد", surahNumber: 13, ayahNumber: 28),
        Ayah(text: "فَاذْكُرُونِي أَذْكُرْكُمْ", surahName: "البقرة", surahNumber: 2, ayahNumber: 152)
    ]

    // اختيار آية بناءً على التاريخ
    private func ayahForDate(_ date: Date) -> Ayah {
        let daysSinceEpoch = Int(date.timeIntervalSince1970 / 86400)
        let index = daysSinceEpoch % sampleAyat.count
        return sampleAyat[abs(index)]
    }

    func placeholder(in context: Context) -> AyahEntry {
        AyahEntry(date: Date(), ayah: ayahForDate(Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (AyahEntry) -> Void) {
        completion(AyahEntry(date: Date(), ayah: ayahForDate(Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AyahEntry>) -> Void) {
        let date = Date()
        let entry = AyahEntry(date: date, ayah: ayahForDate(date))

        // تحديث عند منتصف الليل
        let nextUpdate = Calendar.current.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? date.addingTimeInterval(86400)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}