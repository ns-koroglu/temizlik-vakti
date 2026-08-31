import Foundation

enum Snark {

    /// Kilit sırasında dönen laf sokmalar.
    static let lines: [String] = [
        "Şu sağ alt köşeyi es geçme, seni görüyorum.",
        "Klavyenin arasındaki kırıntı 2019'dan kalma bu arada.",
        "Ekran parlaklığını değil, ekranı sil.",
        "Trackpad'de bir parmak izi galerisi açmışsın.",
        "Mikrofiber bez kullan. Tişörtün bez değil.",
        "Doğrudan ekrana sıvı sıkma. Beze sık. Lütfen.",
        "Space tuşunun altında bir ekosistem var.",
        "Enter'a bugün 4.312 kez bastın, hakkını ver.",
        "Şu yağ lekesi… kahvaltıda ne yedin?",
        "Fan deliklerini de unutma, orası toz müzesi.",
        "Kapak menteşesinin arası. Evet, orası.",
        "M3 çipin bile bu kirden utandı.",
        "Bu arada güzel gidiyorsun. Şaka yaptım, sol tarafa bak.",
        "Cam temizleyici değil, damıtılmış su + mikrofiber.",
        "Ekranda gördüğün nokta toz değil, kırık piksel olabilir. Şaka. Belki.",
        "Kablo girişlerini de sil ama sıvıdan uzak dur.",
        "Klavyeyi ters çevirip hafifçe salla. Hafifçe dedim.",
        "Alt kapak da senin Mac'inin bir parçası.",
        "Şimdi de arkadaki elma logosu. O parlamalı.",
        "Tuşların arasına basınçlı hava, ama çok yakından değil.",
        "Bilerek söylüyorum: caps lock'un kenarı hâlâ kirli.",
        "Şu an klavyeye bassan da olmuyor. Rahatla.",
        "Temizlik bitince kahve dökmemeye çalış, anlaştık mı?",
        "Ekranı dairesel değil, yumuşak yatay hareketlerle sil.",
        "Trackpad'i silerken kenarlarını da dahil et.",
        "Toz alerjin varsa maske takabilirdin.",
        "Sen sildikçe ben tozu sayıyorum. 4.891… 4.892…",
        "Vidalarla oynama, garanti diye bir şey var.",
        "Şarj kablosunun ucu da bir hayli yıpranmış.",
        "Bir sonraki temizlik için takvime not düşelim mi?",
        "Islak bez değil, nemli bez. Aradaki fark: garanti.",
        "Ekrandaki o çizik benim suçum değil.",
        "Bu kadar kir birikmesi için epey emek vermişsin.",
        "Klavye aydınlatmasını kapattım, kir daha net görünüyor.",
        "Hoparlör ızgaraları: kaşifler için son sınır.",
        "Kamera lensini de sil, toplantıda pusluyorsun.",
        "Bu mola sana da iyi geldi, kabul et.",
        "Az kaldı. Ya da değil. Süreyi sen ayarladın.",
        "Alkolü %70'i geçmesin, kaplamaya zarar verir.",
        "Bir de şu köşe. Hep aynı köşe."
    ]

    static let preroll: [String] = [
        "Elini kaldır, kilitliyorum…",
        "Bez hazır mı?",
        "Üç… iki… bir… temizlik vakti!",
        "Yerlerinize, hazır…"
    ]

    static let blocked: [String] = [
        "Boşuna uğraşma, kilitli.",
        "O tuş şu an tatilde.",
        "Basmayı bırak, silmeye devam et.",
        "Tık tık. Cevap yok.",
        "Denedin, olmadı. Beze dön.",
        "Tuşlar seni duymuyor."
    ]

    static let finished: [String] = [
        "Tertemiz. Şimdi 5 dakika buna bakabilirsin.",
        "İşte bu! Yeni gibi oldu.",
        "Pırıl pırıl. Kahveyi uzak tut.",
        "Bitti. Şerefine.",
        "Mac'in teşekkür etti, duymadın mı?"
    ]

    /// Mola ekranında dönen ipuçları.
    static let breakTips: [String] = [
        "20 saniye boyunca ~6 metre uzağa bak. Gözlerin teşekkür edecek.",
        "Birkaç kez bilinçli göz kırp — ekrana bakarken göz kırpma hızın yarıya iniyor.",
        "Omuzlarını kulaklarına çek, üçe say, bırak.",
        "Pencereden dışarı bak. Uzak bir nokta seç ve odaklan.",
        "Ayağa kalk, birkaç adım at. Sırtın hatırlar.",
        "Derin bir nefes: 4 saniye al, 6 saniye ver.",
        "Bileklerini iki yöne de çevir, parmaklarını aç kapa.",
        "Ekranın parlaklığı odanın aydınlığıyla uyumlu mu? Kontrol et.",
        "Su iç. Evet, şimdi.",
        "Boynunu yavaşça sağa sola çevir, zorlama.",
        "Gözlerini 10 saniye kapat, sadece dinlensinler.",
        "Oturuşunu düzelt: ayaklar yerde, ekran göz hizasında."
    ]

    static let breakDone: [String] = [
        "Mola bitti, kaldığın yerden devam.",
        "Gözlerin dinlendi. Hadi bakalım.",
        "Tamamdır, çalışmaya dön.",
        "Şarj oldun. Devam!"
    ]

    static func random(from list: [String], avoiding current: String?) -> String {
        guard list.count > 1 else { return list.first ?? "" }
        var pick = list.randomElement()!
        var guard_ = 0
        while pick == current, guard_ < 8 {
            pick = list.randomElement()!
            guard_ += 1
        }
        return pick
    }
}
