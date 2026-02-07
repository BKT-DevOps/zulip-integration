# Zulip Daily Quiz Integration

Zulip kanallarına günlük quiz soruları gönderen ve 4 saat sonra cevapları paylaşan otomatik sistem.

## Nasıl Çalışır?

```
┌─────────────────────────────────────────────────────────────────┐
│  00:00 UTC (03:00 TR)  │  Rotasyon: Rastgele soru seçilir       │
│  09:00 UTC (12:00 TR)  │  Soru: Quiz görseli Zulip'e gönderilir │
│  13:00 UTC (16:00 TR)  │  Cevap: 4 saat sonra cevap paylaşılır  │
│  01:00 UTC (04:00 TR)  │  Temizlik: 7 günlük mesajlar silinir   │
└─────────────────────────────────────────────────────────────────┘
```

## Klasör Yapısı

```
zulip-integration/
├── 01-db/                      # Soru havuzu
│   ├── AWS/
│   │   ├── q1.png              # Soru görseli
│   │   ├── q1.txt              # Cevap metni (aynı isim!)
│   │   ├── q2.png
│   │   ├── q2.txt
│   │   └── ...
│   ├── Linux/
│   │   ├── permissions.png
│   │   ├── permissions.txt
│   │   └── ...
│   └── Docker/
│       ├── dockerfile.png
│       ├── dockerfile.txt
│       └── ...
├── 02-today/                   # Bugün gönderilecek
│   ├── AWS/
│   ├── Linux/
│   └── Docker/
├── 03-sent/                    # Arşiv (gönderilmiş)
│   ├── AWS/
│   ├── Linux/
│   └── Docker/
└── scripts/
    └── send-quiz.sh
```

## Yeni Soru Ekleme

### 1. Görsel hazırlayın
- Desteklenen formatlar: `.png`, `.jpg`, `.jpeg`, `.gif`
- İsimlendirme: anlamlı isimler kullanın (örn: `ec2-instance-types.png`)

### 2. Cevap dosyası oluşturun
- **Aynı isimde** `.txt` veya `.md` uzantılı dosya
- Örnek: `ec2-instance-types.png` → `ec2-instance-types.txt`

### 3. Dosyaları ekleyin
```bash
# Örnek
cp ec2-instance-types.png 01-db/AWS/
cp ec2-instance-types.txt 01-db/AWS/

git add 01-db/
git commit -m "Add new AWS quiz: EC2 Instance Types"
git push
```

### Cevap Dosyası Örneği

`01-db/AWS/ec2-instance-types.txt`:
```
Doğru cevap: **B) t3.micro**

**Açıklama:**
- t3.micro, AWS Free Tier kapsamında 750 saat/ay ücretsiz kullanılabilir
- 2 vCPU ve 1 GB RAM sunar
- Burstable performans sağlar

Daha fazla bilgi: https://aws.amazon.com/ec2/instance-types/
```

## GitHub Secrets

| Secret | Açıklama | Örnek |
|--------|----------|-------|
| `ZULIP_SITE` | Zulip sunucu URL'i | `https://yourorg.zulipchat.com` |
| `ZULIP_BOT_EMAIL` | Bot email adresi | `quiz-bot@yourorg.zulipchat.com` |
| `ZULIP_API_KEY` | Bot API anahtarı | `XXXXXXXXXXXXXXXXXX` |

> **Not:** Stream ID (`553174`) script'lerde hardcoded olarak tanımlı.

## Workflows

| Workflow | Zamanlama | Açıklama |
|----------|-----------|----------|
| `rotate-quiz-files.yaml` | 00:00 UTC | Her kategoriden rastgele soru seçer |
| `send-daily-quiz.yaml` | 09:00 UTC | Soruları Zulip'e gönderir |
| `send-answers.yaml` | 13:00 UTC | Cevapları paylaşır (4 saat sonra) |
| `cleanup-old-messages.yaml` | 01:00 UTC | 7 günden eski mesajları siler |

## Manuel Tetikleme

GitHub Actions → İlgili workflow → "Run workflow"

## Zulip'te Görünüm

**12:00 - Soru:**
```
Daily Quiz - AWS
────────────────
**AWS Daily Quiz**
[Soru görseli]
```

**16:00 - Cevap:**
```
Daily Quiz - AWS
────────────────
**AWS Quiz Answer**

Doğru cevap: **B) t3.micro**
...
```

## Notlar

- Bir kategoride soru biterse, o kategori atlanır (uyarı verilir)
- Tüm kategoriler boşsa workflow hata verir
- Mesajlar 7 gün sonra otomatik silinir
- Her kategori için ayrı topic oluşturulur
