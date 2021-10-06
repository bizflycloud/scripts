function info_os {
	$Properties = 'Caption', 'CSNAME', 'Version', 'BuildType', 'OSArchitecture'
	Get-CimInstance Win32_OperatingSystem | Select-Object $Properties
}

function get_memory {
	Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object TotalPhysicalMemory, Model
}

function tracert() {
}

function get_wanip {
	$content = curl -UseBasicParsing ipecho.net/plain
	return $content.content
}

function Show-Menu
{
    param (
        [string]$Title = 'My Menu'
    )
    Clear-Host
    Write-Host "================ $Title ================"
    
    Write-Host "y: Press 'y' for yes"
    Write-Host "n: Press 'n' for no"
}


function send_ticket($email, $file_name, $phone_number) {
	$content = Get-Content $file_name
	$props = @{
	Uri = 'https://manage.bizflycloud.vn/ticket/send'
	Method = 'POST'
	ContentType = 'application/x-www-form-urlencoded'
	Body = @{
			FullName = $email
			Email = $email
			Content = $content
			Phone = $phone_number
			}
	Headers = @{
			Cookie='session=.eJzdWNty2kgQ_RWVnnarEEhCIEReFmwcJ4AvAceJUynVSBrBmNElunCxy4_7uF-Ur8mfbI8uIGxDJNc-LeUqa3q6e_p0T_f0zCPvBWRGXL7rxpTWeINQStyZbiCKXBPz3aYiS2qzWeN9tHGwG-kOjuaexXd53wsjwUfE4mt8hF0Ecy5yQIS34o3r_mWQB5tuTOrFVn3pAtNqTiJMSRjx3W88QSgUkkmYcRChAnENbw0D6iErWz4IYRwSx6dYCCMvQDMMBNNi2hJZvUBFlOomWIgDJrQJkeUQxugzGixa45c-Gy89tmSIzTgg0QY-bWLgQPdlH74ty2Nrmp4bIeICOcAzsDhgfCiOPD2EdcBBMFzEIOZi0K1jF1zIjHD8kP9e4_HaJwEOwRWyKEuC2BZkeSopXUnrKmpdTH53wJ7BBMbHxKyuWBdTB-QBCDJa6oQt3JSYuQAHyy1fSlqhyJzvaC_B7Mnv6wTnpl9-QBzEeLMtkMwWnJwZljs6HSb-Sz_33JWSXrospbP462n8MxeQJYQswMjJl8nDlQ5ZJNOvXfAyq7No5xg8x4uI5-ozDA5ANKE_wcTcY6vzoqq2ZVnWlDaEIw6oHm18RmdOJSYLKfiW2ARbepYAfDcKYlzLOQDtt0dwscWkxr0PIxDJ0qAfhwAxDLkBwwd05n4PDOfPL2AEKWNQbOX6TOR6LgF35VlkZOI6zsSzFXUwE6bnUeSH3UaDTdZf5Boxk4WOMT3VtnafTHZWn7B5bpJuqqo27-3IQxbP3bqDXNhyzyxq7GpCA_nkNRQlpAqwRv0drBEkFdfPk6oqrv2UrAwM7Go8L2ulsL0ULMD7fHWxwwcDbgL1lYu85H9liJBSegiCOsvaVMEbUIIWCEcVeJlEAdfpRWE7poNqUCw3PJIuhwxJpUrbzdgLRvd7BaN7MYvC9qSoZv2zY-YNQWAahJ2G0pD25Irl4VOhPOSHCfdpdzJWLBKvHa5Vo7VVIhSUlEb6inQB76S5wztJDl5usu0zqmF9dm5Xx_mi-ymN8Zlkca8OBzuAw-2ZzA3yNqYaxtcaoaowdzqErY7SSF8KF8D2RtNCYlIcRNUzMpN6SypmouVzMBEo2h9H873KMn9LRZlXj0kFqyv3Eifj_6yZMJ03dhOlJSt3FKXQlWwpDhpZoqeo0I-8qa0ohbN8X3EU6qHGopRU-XJQCtJv6sFRiw4UhDJClbuNcmBKtRvHzTvab1SQffrObr9QwfUUcWYzRWGk75e8hAS3u3tsRodfHLZ3t_QKlakj7Fb5WLjYpXfBdLLUS0bkLTAzZdZjv_5MNOjp-E42zC9qf7qmw-bK7aw_ejP9bPihdza4X6jXo_WZdm_fDn-cn8eBQFtIQjfDMGxZvf56cmk7Q2ewECPjcvq5PfSXD-r85GF18f7T6sbDZuvUHA7Q5Tm6GrXGrenH-OozDZQ7rdUJzv2BPbZPbodrR_7q29H9zWq6Hl6u4-srYtzePWCpM9cXN9ZXQxhpXz7eNj9M59e7BxvCHnLMlqrZTWR02qKm2LKpqXazbYgdVcXIammIzx80fvueceiu_FocnrZ77beX2aORKgthEeoxLJjyY62pSKKBpZalKnLLNFRJkxBWbKUtYdRkRYoxC7BpGQp-7D0QSlGjVRe5P75I0jtuRNx4za07bb2tvOOCZbfTqYt_cu-xufAasiiJ8CdxZ-A121s32CTo9CKf79qIhvj_sIdMStiDYPZissJG9k5BfLZR1Loq17VOXW4q7F0NGyTaYrdjSrMMu5jFm18__3a5i9mvn_-Y3GnMGvlM5xg7RnI4ZvvmUD7mr5bINNP4ypZhqUg2hY5sSoJiqrKApKYsWBBbDJFRNUvmn_4FjB8emA.YNWuQw.5XeBKoNyAPDIBiYirT46a7gltSE'
			}
	}
	$Response = Invoke-RestMethod @props
	return $Response
}


function authen($email, $password) {
	$params = @{
		"username"=$email;
		"password"=$password;
		"auth_method"="password";
	}
	$Response = Invoke-WebRequest -UseBasicParsing -Uri 'https://manage.bizflycloud.vn/api/token' -Method POST -Body ($params|ConvertTo-Json) -ContentType "application/json"
	return $Response.StatusCode
}

function main {
	$file_name = Get-Date -Format "'checknetwork'_yyyyMMdd_HHmmss"
	$domain = Read-Host 'Nhap IP hoac domain muon kiem tra: '
	Write-Output "Dang ping, tracert den $domain, vui long doi ket qua..."
	ping -n 10 $domain >> ~\Desktop\$file_name
	TRACERT.EXE $domain >> ~\Desktop\$file_name
	Write-Output "Thong tin keim tra network: " >> ~\Desktop\$file_name
	Write-Output "OS info: " >> ~\Desktop\$file_name
	info_os >> ~\Desktop\$file_name
	get_memory >> ~\Desktop\$file_name
	$wan_ip = get_wanip
	Write-Output "WAN ip: $wan_ip" >> ~\Desktop\$file_name
	Get-Content ~\Desktop\$file_name
	CMD /c PAUSE
	Show-Menu -Title 'My Menu'
	while ($true) {
		$selection = Read-Host 'Ban co muon gui thong tin den bizflycloud khong? [y/n]'
		switch ($selection)
		{
			'y' {
				$auth = 'false'
				$try = 1
				while (($try -le 3) -and ($auth -eq 'false'))
				{
					$email = Read-Host 'Nhap email cua ban: '
					$password = Read-Host 'Nhap password cua ban: '
					$phone = Read-Host 'Nhap so dien thoai cua ban: '
					$code = authen $email $password
					Write-Host $code
					switch ($code)
						{
							'200' {
								Write-Host 'Xac thuc thanh cong'
								$auth='true'
							}
							default {
								Write-Host "Thong tin khong chinh xac, vui long nhap lai thong tin"
								$try++
							} 
						}
				}
				switch ($auth)
					{
						'true' {
							Write-Host "Dang gui ticket..."
							send_ticket $email ~\Desktop\$file_name  $phone
							$selection3 = Read-Host 'Ban co muon xoa file ket qua khong? [y/n]'
							switch ($selection3)
								{
									'y' {
									Remove-Item ~\Desktop\$file_name
									Write-Host 'Removed $file_name'
									return
									} 
									'n' {
									return
									} 
								}
						} 
						'false' {
							Write-Host "Ban da qua 3 lan xac thuc that bai. Vui long gui email kem file ket qua ve support@bizflycloud.vn de duoc hoc tro. Xin cam on!"
							CMD /c PAUSE
							return
						} 
					}
				}
			'n' {
				$selection2 = Read-Host 'Ban co muon xoa file ket qua khong? [y/n]'
				switch ($selection2)
					{
						'y' {
						Remove-Item ~\Desktop\$file_name
						Write-Host 'Removed $file_name'
						return
						} 
						'n' {
						return
						} 
					}
				} 
		}
	}
	Write-Output "Cam on ban da ho tro."
}

main
