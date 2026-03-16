## castSpot

castSpot, macOS için global kısayol (Spotlight/Raycast benzeri) ile çalışan küçük bir Spotify arama ve oynatma aracıdır. Herhangi bir anda sistem genelinde bir arama çubuğu açar, Spotify'da parça arar ve seçtiğiniz şarkıyı anında Spotify uygulamasında oynatır.

- **Platform**: macOS 26.2+
- **Arayüz**: Spotlight/Raycast benzeri floating arama paneli
- **Durum**: MVP (cilalama yapılıyor)

---

## Özellikler

- **Global kısayol**: Varsayılan `Control+Space` ile tüm uygulamaların üstünde arama paneli açılır.
- **Hızlı arama**: Yazarken Spotify Search API ile 150ms debounce'lu autocomplete.
- **Anında oynatma**: Seçilen şarkıyı Spotify uygulamasında AppleScript ile oynatır (Premium zorunlu değil).
- **Token saklama**: Spotify erişim token'ları macOS Keychain üzerinde güvenli saklanır.
- **Her yerde görünür**: Panel tüm Spaces ve fullscreen uygulamalar üzerinde floating olarak belirir.

---

## Mimarinin Kısa Özeti

- **Tamamen client-side**: Her kullanıcı kendi Spotify hesabıyla konuşur, hiçbir backend/proxy yoktur.
- **Kimlik doğrulama**: Spotify OAuth 2.0 PKCE akışı, redirect `castspot://callback`.
- **Global hotkey**: Carbon `RegisterEventHotKey` (SPM bağımlılığı yok, Accessibility izni gerektirmez).
- **UI**: SwiftUI + AppKit `NSPanel` kombinasyonu.
- **Token saklama**: macOS Keychain (Security framework).
- **Oynatma**: `NSAppleScript` ile `play track "spotify:track:ID"`.
- **Sandbox**: Kapalı (`ENABLE_APP_SANDBOX = NO`), sadece `com.apple.security.network.client = true` yetkisi.

Projenin daha detaylı teknik dokümantasyonu için `.claude/castSpot_CLAUDE.md` dosyasına bakabilirsiniz.

---

## Kurulum

castSpot şu anda geliştirme aşamasındadır. Dağıtım hedefi:

- Kaynak kod: GitHub üzerinde open-source.
- Binary: GitHub Releases altında notarize edilmiş `.pkg` installer.

Bu repo şu an için öncelikle geliştiriciler içindir. Kullanıcı dostu installer hazır olduğunda bu bölüm güncellenecektir.

---

## Geliştiriciler için

### Gereksinimler

- Xcode (Swift 6 desteğiyle)
- macOS 26.2 veya üstü
- Bir Spotify hesabı

### Projeyi Çalıştırma

1. Repo'yu klonlayın:

```bash
git clone https://github.com/<kullanici-adi>/castSpot.git
cd castSpot
```

2. Projeyi Xcode ile açın.
3. `SpotifyAuth.swift` içindeki `clientID` alanını kendi Spotify uygulamanızın Client ID'si ile güncelleyin:
   - `developer.spotify.com` → Dashboard → Create App
   - Redirect URI olarak `castspot://callback` ekleyin.
4. Uygulamayı Xcode üzerinden çalıştırın.

İlk çalıştırmada, Onboarding ekranında "Connect Spotify" adımı ile OAuth akışı başlar. Safari açılır, kendi hesabınızla giriş yaptıktan sonra uygulama `castspot://callback` URL scheme'i ile token'ı alır ve Keychain'e kaydeder.

---

## Kullanım

- Uygulama arka planda bir menü çubuğu ikonu olarak çalışır.
- Varsayılan global kısayol: **Control+Space**.
  - Eğer bu kısayol macOS'ta Input Source (klavye dili) değiştirme kısayoluna atanmışsa:
    - System Settings → Keyboard → Shortcuts → Input Sources bölümünden devre dışı bırakmalısınız.
- Kısayola bastığınızda:
  - Ekranın ortasında floating bir arama çubuğu açılır.
  - Parça adını yazmaya başladığınızda autocomplete sonuçları listelenir.
  - Yön tuşlarıyla seçip Enter'a bastığınızda şarkı Spotify uygulamasında oynatılır.

---

## Proje Yapısı (özet)

```text
castSpot/
├── castSpotApp.swift          # @main, NSApplicationDelegateAdaptor
├── AppDelegate.swift          # NSStatusItem, global hotkey, OAuth URL handler
├── Info.plist                 # LSUIElement, URL scheme, AppleScript izinleri
├── castSpot.entitlements      # Sandbox ve network client yetkileri
├── UI/
│   ├── SearchPanel/
│   └── Onboarding/
├── Spotify/
└── Settings/
```

Detaylar için `.claude/castSpot_CLAUDE.md` içindeki tam ağaç yapısına bakabilirsiniz.

---

## Geliştirme Durumu ve Yol Haritası

Tamamlanan başlıca öğeler:

- ✅ Uygulama iskeleti (AppDelegate, NSStatusItem, Dock gizleme)
- ✅ NSPanel + SearchView (tüm ekranlarda floating pencere)
- ✅ Global hotkey (Carbon `RegisterEventHotKey`)
- ✅ Spotify OAuth (PKCE, URL scheme callback, Keychain entegrasyonu)
- ✅ Search API (150ms debounce, autocomplete, `NSCache`)
- ✅ Playback (NSAppleScript ile çalma)
- ✅ Onboarding (Connect Spotify ekranı)

Planlanan/eksik öğeler:

- ⬜ Settings ekranında kısayol değiştirme işlevinin tamamlanması
- ⬜ `SpotifyAuth.swift` içinde gerçek Client ID ile yapılandırma
- ⬜ Notarization ve `.pkg` installer oluşturma

---

## Katkıda Bulunma

Proje şu anda erken aşamada olsa da, issue açarak veya öneri PR'ları göndererek katkıda bulunabilirsiniz. Özellikle aşağıdaki alanlarda katkı değerlidir:

- Arayüz iyileştirmeleri (SwiftUI/NSPanel)
- Ayarlar ekranı ve kısayol yönetimi
- Dağıtım/CI ayarları (notarization, .pkg pipeline)

---

## Lisans

Lisans dosyası henüz eklenmediyse, bu proje için uygun bir open-source lisans (örneğin MIT ya da Apache-2.0) seçilip `LICENSE` dosyası eklenmelidir.
