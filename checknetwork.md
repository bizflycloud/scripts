---
title: "Hướng dẫn kiểm tra network đến domain, ip , thông tin cấu hình máy client trên windows, linux, mac os. Sau đó, có thể gửi thông tin trên đến bizflycloud support"
draft: false
---


**Trên Windows**:<br />
	Bước 1: Mở PowerShell (Bấm Start gõ PowerShell để mở Windows PowerShell)<br />
	Bước 2: Copy & Paste 3 dòng lệnh sau vào PowerShell:<br />

	Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
	Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
	powershell -Command ("Invoke-WebRequest -Uri https://raw.githubusercontent.com/laduygaga/scripts/master/checknetwork.ps1  -OutFile ~\Desktop\checknetwork.ps1")
	powershell  ~\Desktop\checknetwork.ps1

	Nhập Y, để chọn Yes

	Khi chạy xong, chương trình sẽ hỏi có muốn gửi thông tin cho Bizfly Cloud không, bấm y để gửi.


**Trên Linux**:<br />
	Bước 1: Mở Terminal<br />
	Bước 2: Copy & Paste lại vào Terminal đoạn sau:<br />

	[[ -e ./checknetwork.sh ]] && rm -v ./checknetwork.sh; bash <(curl -sL https://raw.githubusercontent.com/laduygaga/scripts/master/checknetwork.sh)
)


**Trên Mac**:<br />
	Bước 1: Mở Terminal <br />
	Bước 2: Copy & Paste lại vào Terminal đoạn sau:<br />

	[[ -e ./checknetwork_mac.sh ]] && rm -v ./checknetwork_mac.sh; bash <(https://raw.githubusercontent.com/laduygaga/scripts/master/checknetwork_mac.sh)

