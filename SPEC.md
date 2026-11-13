# Shadow Talk — Đặc tả v0.1 (13/11/2026)

App Android luyện nói tiếng Anh kiểu **shadowing**, dùng chủ yếu **khi đang đi xe**.

## 1. Mục tiêu
Nghe 1 câu → nói lại → chấm ngay → tự sang câu kế. Tắt màn hình vẫn chạy. Lọc ồn.
Thao tác: nút to trên màn / nút tai nghe Bluetooth / lệnh giọng — mắt không cần nhìn vẫn học được.

## 2. Yêu cầu chức năng
- **F1 Thư viện**: 3 chủ đề (Giao tiếp hằng ngày, Công việc/bán hàng, Du lịch) × cấp độ A1–C1.
  Alpha: A2/B1/B2, 3 bài/chủ đề, mỗi bài 8 câu (EN + dịch VI + audio giọng Anh-Mỹ đóng gói sẵn, sinh bằng edge-tts `en-US-AndrewNeural`, rate -4%).
- **F2 Màn Luyện tập**:
  - *Chế độ đi xe* (mặc định): tự phát câu → tự ghi khi nói xong (VAD ngắt im lặng ~1.5s) → chấm → đọc điểm bằng giọng → tự sang câu kế.
  - *Chế độ chậm*: bấm từng bước (nghe lại / ghi lại / chấm lại).
  - Hiển thị: điểm to 0–100, tô màu từng từ (xanh = đúng, đỏ = sai/thiếu, vàng = lệch nhẹ), replay giọng mẫu / giọng mình.
- **F3 Chấm offline**: nhận dạng giọng trên máy (sherpa-onnx, model zipformer EN ~50MB, tải 1 lần khi có WiFi).
  So khớp từng từ (chuẩn hoá + Levenshtein): điểm = 70% khớp từ + 20% độ phủ (không bỏ từ) + 10% tốc độ nói hợp lý.
  Có mạng + key Azure → chấm sâu thêm (phát âm từng âm, ngữ điệu) qua proxy Render, hiện như "chi tiết nâng cao".
- **F4 Lọc ồn**: Android NoiseSuppressor + EchoCanceler (WebRTC), high-pass 85 Hz tự viết, ưu tiên mic tai nghe Bluetooth khi cắm (SCO).
- **F5 Chạy nền**: Foreground Service (mediaPlayback + microphone); tắt màn vẫn nghe/phát/chấm; cuộc gọi đến → tự pause + lưu trạng thái, kết thúc gọi tự tiếp tục.
- **F6 Điều khiển**: nút to 2 cái (Lặp lại / Tiếp); tai nghe: ⏯ đơn = lặp lại câu, giữ ≥1s = sang câu, ⏭ = sang câu; lệnh giọng: "tiếp / next", "lặp lại / repeat" (chỉ kích hoạt khi nói trọn từ lệnh).
- **F7 Nội dung của tôi**: dán text → tự tách câu + TTS máy đọc; nhập file audio (mp3/wav) + transcript → cắt theo im lặng, ghép 1:1 với câu.
- **F8 Tiến độ**: streak ngày, điểm tốt nhất từng bài, số câu luyện — lưu cục bộ.
- **F9 Cài đặt**: tốc độ phát 0.6–1.0x, thời gian chờ trước ghi, bật/tắt chế độ tự động, chọn thiết bị âm thanh, ngưỡng điểm "đạt" (mặc định 70).

## 3. Kiến trúc
- **Flutter** (Android-only, UI tiếng Việt, dark, chữ to).
- Audio: `just_audio_background` (MediaSession → nút tai nghe), `record` (foreground service), DSP high-pass + VAD tự viết Dart.
- STT offline: plugin sherpa-onnx flutter; model tải lần đầu, cache trong app.
- Azure (tuỳ chọn): proxy nhỏ trên Render `/assess` để giấu key.
- Nội dung: `content/lessons.json` + `content/audio/<bài>/NN.mp3` đóng gói asset.
- CI: GitHub Actions build APK release, publish vào Release của repo `shadow-talk`.

## 4. Tiêu chí UAT (cổng GO)
- **U1 (P0)**: Luyện 10 phút màn hình tắt: phát/ghi/chấm liên tục, không mất tiến độ.
- **U2 (P0)**: Sau khi nói xong, điểm hiện ≤ 3 giây (offline).
- **U3 (P0)**: Cắm tai nghe Bluetooth: ghi bằng mic tai nghe; nút tai nghe hoạt động đúng.
- **U4 (P1)**: Lệnh giọng "tiếp"/"lặp lại" hoạt động khi mở radio nhỏ.
- **U5 (P1)**: Dán 1 đoạn text → ra bài luyện được (tách câu + TTS phát được).
- **U6 (P2)**: Phòng im, đọc đúng theo mẫu: điểm ≥ 80.

## 5. Trạng thái / Nhật ký
- 13/11: chốt yêu cầu + duyệt kế hoạch 9 bước (todo đã lập).
- Alpha pack: 9 bài × 8 câu = 72 câu (`content/lessons.json`) + 72 mp3 (`en-US-AndrewNeural`, rate -4%).
- Mock UI: `mock.html` — màn Luyện tập + màn Danh sách bài.
- **S3 XONG (13/11)**: khung Flutter đầy đủ trong `app/` — 4 tab (Bài học/Của tôi/Tiến độ/Cài đặt) + màn Luyện tập; phát nền just_audio_background; ghi stream PCM 16k qua record 5.x (NS/echoCancel/AGC) + BiquadHPF 85 Hz + VAD tự dừng; SCO Bluetooth qua MethodChannel (`MainActivity.kt`); manifest đầy đủ quyền foreground mic; CI `build-apk.yml` (flutter create sinh phần Android thiếu → sync-assets → analyze → test → build APK → publish release); 5 unit test DSP/VAD/model. CHƯA compile-verify — push lần đầu lên GitHub mới xác nhận.
- Cần từ anh: **GitHub token MỚI (classic, scope `repo`, hạn 30 ngày)** để push sớm — CI build xác nhận khung trước khi viết s4–s6; đồng thời **thu hồi token cũ `github_pat_11CTPD6DA0...` đã lộ**. Key Azure chỉ cần khi tới s8.
- Nhớ: credit có thể đứt giữa chừng — trạng thái luôn ghi ở file này + Memory; phiên mới "init lại" = đọc SPEC này + todo + Memory rồi làm tiếp từ bước kế.
- 13/11 (buoi chieu): **S3 CI-verified — APK dau tien build + release thanh cong** (run 8). Repo: github.com/gamedior13-sys/shadow-talk (public). Cac loi da vuot: just_audio_background chi co ban beta (^0.0.1-beta.17); analyze: bo debug param + bo android RecordConfig; test: sua he so b1 high-pass (b1 = -2*bb — test DC bat ra dung loi); manifest: them android:exported cho AudioService; **bo package record** (ecosystem tu mau thuan: platform_interface co tham so request moi vs record_linux 0.7.2 cu, khong co cap nao khop) → tu viet AudioRecord native + RecordingService (FGS type microphone) + EventChannel stream PCM. APK 51.3MB: releases/tag/build-8 (versionName 0.3.0, versionCode 108). Push dung token ghp_ (scope repo+workflow) da luu trong ~\.git-credentials; file .gh-tokens.txt chua token cu da xoa.

## 2.1. Yeu cau v0.4 (13/11 — anh Phong, 6 y)
1. **Tu dong cap nhat bai moi moi ngay + nut lam moi**: app fetch content/lessons.json tu raw GitHub (main) 1 lan/ngay khi mo app + nut Lam moi o man Bai hoc; bai moi (them rev) tu tai audio ve documents/.
2. **Khong hien het noi dung**: theo lo trinh — chi level hien tai mo, cac level sau bi khoa (mo bang bai kiem tra); man luyen: chu EN an mac dinh, co nut 'Hien chu'.
3. **Cham diem moi buoi hoc**: S4 cham offline (moonshine-tiny-en 28MB quantized 2026-02-27, offline zipformer thay the) + tong ket buoi: diem tung cau, diem trung binh, tu sai, luu lich su buoi.
4. **Bai kiem tra 7 ngay**: du 7 ngay luyen ke tu lan kiem tra cu → mo 'Bai kiem tra nang cap' (8 cau ngau nhien cua level hien tai, dat nguong diem → len level ke).
5. **Danh gia trinh do ban dau**: lan dau mo app → kiem tra 6 cau (2 cau/level A2/B1/B2) → xep level phu hop, mo lo trinh theo level do.
6. **UX/UI lam moi**: theme sang, toi gian — trang #F6F8FB, xanh #2563EB (chinh/tien do/tu dung), do #DC2626 (sai/thieu), chu #0F172A; bo theme dark amber cu.
- Thuat toan diem: 70% khop tu + 20% do phu (khong bo tu) + 10% toc do noi hop ly; Levenshtein align pure Dart co unit test.
- Model: github k2-fsa release asr-models/sherpa-onnx-moonshine-tiny-en-quantized-2026-02-27.tar.bz2 (28MB, encoder_model.ort + decoder_model_merged.ort + tokens.txt), tai 1 lan, offline 100%.
