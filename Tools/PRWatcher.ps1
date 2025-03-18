#Copyright 2023 Microsoft Corporation
#Author: Stephen Gillie
#Title: PRWatcher v0.8.2
#Created: 2/15/2023
#Updated: 6/27/2023
#Notes: Streamlines WinGet-pkgs manifest PR moderator approval by watching the clipboard - copy a PR title to your clipboard, and Watch-PRTitles attempts to parse the PackageIdentifier and version number, gathers the version from WinGet, and gives feedback in your Powershell console. Also outputs valid titles to a logging file. Freeing moderators to focus on approving and helping.
#Update log:
#0.8 Update PackageIdentifier and PackageVersion detection by starting with the manifest file.
#0.8.1 Update WinGet version in Create-Sandbox.
#0.8.2 Make new version detection of semantic type.

$CountrySet = 'Default', 'Warm', 'Cool', 'Random', 'Afghanistan', 'Albania', 'Algeria', 'American Samoa', 'Andorra', 'Angola', 'Anguilla', 'Antigua And Barbuda', 'Argentina', 'Armenia', 'Aruba', 'Australia', 'Austria', 'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados', 'Belarus', 'Belgium', 'Belize', 'Benin', 'Bermuda', 'Bhutan', 'Bolivia', 'Bosnia And Herzegovina', 'Botswana', 'Bouvet Island', 'Brazil', 'Brunei Darussalam', 'Bulgaria', 'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cambodia', 'Cameroon', 'Canada', 'Central African Republic', 'Chad', 'Chile', 'China', 'Colombia', 'Comoros', 'Cook Islands', 'Costa Rica', 'Croatia', 'Cuba', 'CuraΓö£┬║ao', 'Cyprus', 'Czechia', "CΓö£Γöñte D'Ivoire", 'Democratic Republic Of The Congo', 'Denmark', 'Djibouti', 'Dominica', 'Dominican Republic', 'Ecuador', 'Egypt', 'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini', 'Ethiopia', 'Fiji', 'Finland', 'France', 'French Polynesia', 'Gabon', 'Gambia', 'Georgia', 'Germany', 'Ghana', 'Greece', 'Grenada', 'Guatemala', 'Guinea', 'Guinea-Bissau', 'Guyana', 'Haiti', 'Holy See (Vatican City State)', 'Honduras', 'Hungary', 'Iceland', 'India', 'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Israel', 'Italy', 'Jamaica', 'Japan', 'Jordan', 'Kazakhstan', 'Kenya', 'Kiribati', 'Kuwait', 'Kyrgyzstan', 'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya', 'Liechtenstein', 'Lithuania', 'Luxembourg', 'Madagascar', 'Malawi', 'Malaysia', 'Maldives', 'Mali', 'Malta', 'Marshall Islands', 'Mauritania', 'Mauritius', 'Mexico', 'Micronesia', 'Moldova', 'Monaco', 'Mongolia', 'Montenegro', 'Morocco', 'Mozambique', 'Myanmar', 'Namibia', 'Nauru', 'Nepal', 'Netherlands', 'New Zealand', 'Nicaragua', 'Niger', 'Nigeria', 'Niue', 'Norfolk Island', 'North Korea', 'North Macedonia', 'Norway', 'Oman', 'Pakistan', 'Palau', 'Palestine', 'Panama', 'Papua New Guinea', 'Paraguay', 'Peru', 'Philippines', 'Pitcairn Islands', 'Poland', 'Portugal', 'Qatar', 'Republic Of The Congo', 'Romania', 'Russian Federation', 'Rwanda', 'Saint Kitts And Nevis', 'Saint Lucia', 'Saint Vincent And The Grenadines', 'Samoa', 'San Marino', 'Sao Tome And Principe', 'Saudi Arabia', 'Senegal', 'Serbia', 'Seychelles', 'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia', 'Solomon Islands', 'Somalia', 'South Africa', 'South Korea', 'South Sudan', 'Spain', 'Sri Lanka', 'Sudan', 'Suriname', 'Sweden', 'Switzerland', 'Syrian Arab Republic', 'Tajikistan', 'Tanzania', ' United Republic Of', 'Thailand', 'Togo', 'Tonga', 'Trinidad And Tobago', 'Tunisia', 'Turkey', 'Turkmenistan', 'Tuvalu', 'Uganda', 'Ukraine', 'United Arab Emirates', 'United Kingdom', 'United States', 'Uruguay', 'Uzbekistan', 'Vanuatu', 'Venezuela', 'Vietnam', 'Yemen', 'Zambia', 'Zimbabwe', 'Åland Islands'

Function Watch-PRTitles {
	[CmdletBinding()]
	param(
		[switch]$noNew,
		$LogFile = '.\PR.txt',
		$AuthFile = '.\Auth.csv',
		[ValidateSet('Default', 'Warm', 'Cool', 'Random', 'Afghanistan', 'Albania', 'Algeria', 'American Samoa', 'Andorra', 'Angola', 'Anguilla', 'Antigua And Barbuda', 'Argentina', 'Armenia', 'Aruba', 'Australia', 'Austria', 'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados', 'Belarus', 'Belgium', 'Belize', 'Benin', 'Bermuda', 'Bhutan', 'Bolivia', 'Bosnia And Herzegovina', 'Botswana', 'Bouvet Island', 'Brazil', 'Brunei Darussalam', 'Bulgaria', 'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cambodia', 'Cameroon', 'Canada', 'Central African Republic', 'Chad', 'Chile', 'China', 'Colombia', 'Comoros', 'Cook Islands', 'Costa Rica', 'Croatia', 'Cuba', 'CuraΓö£┬║ao', 'Cyprus', 'Czechia', "CΓö£Γöñte D'Ivoire", 'Democratic Republic Of The Congo', 'Denmark', 'Djibouti', 'Dominica', 'Dominican Republic', 'Ecuador', 'Egypt', 'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini', 'Ethiopia', 'Fiji', 'Finland', 'France', 'French Polynesia', 'Gabon', 'Gambia', 'Georgia', 'Germany', 'Ghana', 'Greece', 'Grenada', 'Guatemala', 'Guinea', 'Guinea-Bissau', 'Guyana', 'Haiti', 'Holy See (Vatican City State)', 'Honduras', 'Hungary', 'Iceland', 'India', 'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Israel', 'Italy', 'Jamaica', 'Japan', 'Jordan', 'Kazakhstan', 'Kenya', 'Kiribati', 'Kuwait', 'Kyrgyzstan', 'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya', 'Liechtenstein', 'Lithuania', 'Luxembourg', 'Madagascar', 'Malawi', 'Malaysia', 'Maldives', 'Mali', 'Malta', 'Marshall Islands', 'Mauritania', 'Mauritius', 'Mexico', 'Micronesia', 'Moldova', 'Monaco', 'Mongolia', 'Montenegro', 'Morocco', 'Mozambique', 'Myanmar', 'Namibia', 'Nauru', 'Nepal', 'Netherlands', 'New Zealand', 'Nicaragua', 'Niger', 'Nigeria', 'Niue', 'Norfolk Island', 'North Korea', 'North Macedonia', 'Norway', 'Oman', 'Pakistan', 'Palau', 'Palestine', 'Panama', 'Papua New Guinea', 'Paraguay', 'Peru', 'Philippines', 'Pitcairn Islands', 'Poland', 'Portugal', 'Qatar', 'Republic Of The Congo', 'Romania', 'Russian Federation', 'Rwanda', 'Saint Kitts And Nevis', 'Saint Lucia', 'Saint Vincent And The Grenadines', 'Samoa', 'San Marino', 'Sao Tome And Principe', 'Saudi Arabia', 'Senegal', 'Serbia', 'Seychelles', 'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia', 'Solomon Islands', 'Somalia', 'South Africa', 'South Korea', 'South Sudan', 'Spain', 'Sri Lanka', 'Sudan', 'Suriname', 'Sweden', 'Switzerland', 'Syrian Arab Republic', 'Tajikistan', 'Tanzania, United Republic Of', 'Thailand', 'Togo', 'Tonga', 'Trinidad And Tobago', 'Tunisia', 'Turkey', 'Turkmenistan', 'Tuvalu', 'Uganda', 'Ukraine', 'United Arab Emirates', 'United Kingdom', 'United States', 'Uruguay', 'Uzbekistan', 'Vanuatu', 'Venezuela', 'Vietnam', 'Yemen', 'Zambia', 'Zimbabwe', 'Åland Islands')]
		$Chromatic = 'Default',
		$oldclip = '',
		$hashPRRegex = '[#][0-9]{5,6}',
		$AuthList = ''
	)
	if (Test-Path $AuthFile) {
		$AuthList = Get-Content $AuthFile | ConvertFrom-Csv
		Write-Host "Using Auth file $AuthFile" -f green
	} else {
		Write-Host "Auth file $AuthFile not found!" -f red
	}
	Write-Host "Loaded $($AuthList.count) Auth file entries."
	while ($true) {
		$clip2 = (Get-Clipboard)
		$clip = $clip2 | Select-String '[#][0-9]{5,6}$';
		#$clip = ((Get-Clipboard) -join "") -replace "PackageVersion:"," version" | select-string -NotMatch "^[c][:]";
		if ($clip) {
			if (Compare-Object $clip $oldclip) {
				if ((Get-Command Get-Status).name) {
			(Get-Status | Where-Object { $_.status -eq 'ValidationComplete' })
				}
				$timevar = (Get-Date -Format T) + ':'
				$copyClip = $false
				$noRecord = $false

				$title = $clip -split ': '
				if ($title[1]) {
					$title = $title[1] -split ' '
				} else {
					$title = $title -split ' '
				}
				#Split the title by spaces. Try extracting the version location as the next item after the word "version", and if that fails, use the 2nd to the last item, then 3rd to last, and 4th to last. For some reason almost everyone puts the version number as the last item, and GitHub appends the PR number.
				$prVerLoc = ($title | Select-String 'version').linenumber
				#Version is on the line before the line number, and this set indexes with 1 - but the following array indexes with 0, so the value is automatically transformed by the index mismatch.
				try {
					[System.Version]$prVersion = (($clip2 | Select-String 'PackageVersion')[0] -split ': ')[1] -replace "'", '' -replace '"', ''
				} catch {
					try {
						[System.Version]$prVersion = (($clip2 | Select-String 'PackageVersion')[1] -split ': ')[1]
					} catch {
						if ($null -ne $prVerLoc) {
							try {
								[System.Version]$prVersion = $title[$prVerLoc]
							} catch {
								[string]$prVersion = $title[$prVerLoc]
							}
						} else {
							#Otherwise we have to go hunting for the version number.
							try {
								[System.Version]$prVersion = $title[-1]
							} catch {
								try {
									[System.Version]$prVersion = $title[-2]
								} catch {
									try {
										[System.Version]$prVersion = $title[-3]
									} catch {
										try {
											[System.Version]$prVersion = $title[-4]
										} catch {
											#If it's not a semantic version, guess that it's the 2nd to last, based on the above logic.
											[string]$prVersion = $title[-2]
										}
									}
								}
							}; #end try
						}; #end try
					}; #end if null
				}; #end try
				$validColor = 'green'
				$invalidColor = 'red'
				$cautionColor = 'yellow'

				Switch ($Chromatic) {
					#Color schemes, to accomodate needs and also add variety.
					'Default' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Warm' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Cool' {
						$validColor = 'Green'
						$invalidColor = 'Blue'
						$cautionColor = 'Cyan'
					}
					'Random' {
						$Chromatic = ($CountrySet | Get-Random)
						Write-Host "Using CountrySet $Chromatic" -f green
					}
					#https://www.flagpictures.com/countries/flag-colors/
					'Afghanistan' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Albania' {
						$validColor = 'DarkGray'
						$invalidColor = 'Red'
					}
					'Algeria' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'American Samoa' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Andorra' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Angola' {
						$validColor = 'DarkGray'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Anguilla' {
						$invalidColor = 'Blue'
						$cautionColor = 'White'
					}
					'Antigua And Barbuda' {
						$invalidColor = 'Red'
						$validColor = 'DarkGray'
						$invalidColor = 'Blue'
						$validColor = 'White'
						$cautionColor = 'Yellow'
					}
					'Argentina' {
						$validColor = 'White'
						$cautionColor = 'Cyan'
					}
					'Armenia' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'DarkYellow'
					}
					'Aruba' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Australia' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Austria' {
						$validColor = 'White'
						$invalidColor = 'Red'
					}
					'Azerbaijan' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Cyan'
					}
					'Bahamas' {
						$validColor = 'DarkGray'
						$invalidColor = 'Cyan'
						$cautionColor = 'Yellow'
					}
					'Bahrain' {
						$validColor = 'White'
						$invalidColor = 'Red'
					}
					'Bangladesh' {
						$validColor = 'Green'
						$invalidColor = 'Red'
					}
					'Barbados' {
						$validColor = 'DarkGray'
						$invalidColor = 'Blue'
						$cautionColor = 'DarkYellow'
					}
					'Belarus' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Belgium' {
						$validColor = 'DarkGray'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Belize' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Benin' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Bermuda' {
						$invalidColor = 'Red'
					}
					'Bhutan' {
						$validColor = 'DarkRed'
						$invalidColor = 'DarkYellow'
						$cautionColor = 'White'
					}
					'Bolivia' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Bosnia And Herzegovina' {
						$invalidColor = 'Blue'
						$validColor = 'White'
						$cautionColor = 'Yellow'
					}
					'Botswana' {
						$validColor = 'DarkGray'
						$invalidColor = 'White'
						$cautionColor = 'Cyan'
					}
					'Bouvet Island' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Brazil' {
						$validColor = 'Green'
						$invalidColor = 'Blue'
						$cautionColor = 'DarkYellow'
					}
					'Brunei Darussalam' {
						$validColor = 'DarkGray'
						$invalidColor = 'Red'
						$validColor = 'White'
						$cautionColor = 'Yellow'
					}
					'Bulgaria' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Burkina Faso' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Burundi' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Cabo Verde' {
						$validColor = 'White'
						$invalidColor = 'DarkYellow'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Cambodia' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Cameroon' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Canada' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Central African Republic' {
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
						$cautionColor = 'Yellow'
					}
					'Chad' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Chile' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'China' {
						$invalidColor = 'Red'
						$cautionColor = 'DarkYellow'
					}
					'Colombia' {
						$nvalidColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Comoros' {
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
						$cautionColor = 'Yellow'
					}
					'Cook Islands' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Costa Rica' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Croatia' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Cuba' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Curaçao' {
						$validColor = 'White'
						$invalidColor = 'Blue'
						$cautionColor = 'Yellow'
					}
					'Cyprus' {
						$validColor = 'White'
						$invalidColor = 'Blue'
					}
					'Czechia' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					"Côte D'Ivoire" {
						$validColor = 'Green'
						$invalidColor = 'DarkYellow'
						$cautionColor = 'White'
					}
					'Democratic Republic Of The Congo' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Denmark' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Djibouti' {
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Cyan'
					}
					'Dominica' {
						$validColor = 'Green'
						$validColor = 'DarkGray'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Dominican Republic' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Ecuador' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Egypt' {
						$validColor = 'DarkGray'
						$invalidColor = 'DarkYellow'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'El Salvador' {
						$validColor = 'White'
						$invalidColor = 'DarkYellow'
						$cautionColor = 'Blue'
					}
					'Equatorial Guinea' {
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Eritrea' {
						$validColor = 'Green'
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Estonia' {
						$validColor = 'DarkGray'
						$invalidColor = 'Blue'
						$cautionColor = 'White'
					}
					'Eswatini' {
						$validColor = 'DarkGray'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
						$cautionColor = 'Yellow'
					}
					'Ethiopia' {
						$validColor = 'Green'
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Fiji' {
						$validColor = 'White'
						$validColor = 'DarkBlue'
						$invalidColor = 'DarkYellow'
						$invalidColor = 'Red'
						$cautionColor = 'Cyan'
					}
					'Finland' {
						$validColor = 'White'
						$invalidColor = 'Blue'
					}
					'France' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'French Polynesia' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$invalidColor = 'Blue'
						$cautionColor = 'DarkYellow'
					}
					'Gabon' {
						$validColor = 'Green'
						$invalidColor = 'Blue'
						$cautionColor = 'Yellow'
					}
					'Gambia' {
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Georgia' {
						$validColor = 'White'
						$invalidColor = 'Red'
					}
					'Germany' {
						$validColor = 'DarkGray'
						$invalidColor = 'Red'
						$cautionColor = 'DarkYellow'
					}
					'Ghana' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Greece' {
						$validColor = 'White'
						$invalidColor = 'Blue'
					}
					'Grenada' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Guatemala' {
						$validColor = 'White'
						$invalidColor = 'Blue'
					}
					'Guinea' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Guinea-Bissau' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Guyana' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Haiti' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
					}
					'Holy See (Vatican City State)' {
						$validColor = 'White'
						$cautionColor = 'Yellow'
					}
					'Honduras' {
						$validColor = 'White'
						$invalidColor = 'Blue'
					}
					'Hong Kong' {
						$validColor = 'White'
						$invalidColor = 'Red'
					}
					'Hungary' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Iceland' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'India' {
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Blue'
						$cautionColor = 'DarkYellow'
					}
					'Indonesia' {
						$validColor = 'White'
						$invalidColor = 'Red'
					}
					'Iran' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Iraq' {
						$invalidColor = 'Red'
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$cautionColor = 'White'
					}
					'Ireland' {
						$validColor = 'Green'
						$invalidColor = 'Blue'
					}
					'Israel' {
						$validColor = 'White'
						$invalidColor = 'Blue'
					}
					'Italy' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Jamaica' {
						$validColor = 'Green'
						$invalidColor = 'DarkGray'
						$cautionColor = 'DarkYellow'
					}
					'Japan' {
						$validColor = 'White'
						$invalidColor = 'Red'
					}
					'Jordan' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Kazakhstan' {
						$cautionColor = 'Yellow'
						$invalidColor = 'Blue'
					}
					'Kenya' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Kiribati' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$invalidColor = 'Blue'
						$cautionColor = 'DarkYellow'
					}
					'Kuwait' {
						$validColor = 'Green'
						$validColor = 'DarkGray'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Kyrgyzstan' {
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Laos' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Latvia' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Lebanon' {
						$invalidColor = 'Red'
						$validColor = 'Green'
						$cautionColor = 'White'
					}
					'Lesotho' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Blue'
						$cautionColor = 'White'
					}
					'Liberia' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Libya' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Liechtenstein' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
					}
					'Lithuania' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Luxembourg' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Cyan'
					}
					'Macao' {
						$validColor = 'Green'
						$cautionColor = 'White'
					}
					'Madagascar' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Malawi' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'DarkGray'
					}
					'Malaysia' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$invalidColor = 'DarkBlue'
						$cautionColor = 'Yellow'
					}
					'Maldives' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Mali' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Malta' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Marshall Islands' {
						$invalidColor = 'Blue'
						$invalidColor = 'DarkYellow'
						$cautionColor = 'White'
					}
					'Mauritania' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Mauritius' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$invalidColor = 'Blue'
						$cautionColor = 'Yellow'
					}
					'Mexico' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Micronesia' {
						$invalidColor = 'Blue'
						$cautionColor = 'White'
					}
					'Moldova' {
						$validColor = 'Blue'
						$invalidColor = 'DarkYellow'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Monaco' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Mongolia' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Montenegro' {
						$invalidColor = 'Red'
						$cautionColor = 'DarkYellow'
					}
					'Morocco' {
						$validColor = 'Green'
						$invalidColor = 'Red'
					}
					'Mozambique' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Myanmar' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
						$cautionColor = 'White'
					}
					'Namibia' {
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Nauru' {
						$invalidColor = 'Blue'
						$validColor = 'White'
						$cautionColor = 'Yellow'
					}
					'Nepal' {
						$validColor = 'DarkRed'
						$invalidColor = 'Blue'
						$cautionColor = 'White'
					}
					'Netherlands' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'New Zealand' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Nicaragua' {
						$invalidColor = 'Blue'
						$cautionColor = 'White'
					}
					'Niger' {
						$validColor = 'Green'
						$cautionColor = 'White'
						$cautionColor = 'DarkYellow'
					}
					'Nigeria' {
						$validColor = 'Green'
						$cautionColor = 'White'
					}
					'Niue' {
						$validColor = 'DarkYellow'
					}
					'Norfolk Island' {
						$validColor = 'Green'
						$cautionColor = 'White'
					}
					'North Korea' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'North Macedonia' {
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Norway' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Oman' {
						$invalidColor = 'Red'
						$validColor = 'Green'
						$cautionColor = 'White'
					}
					'Pakistan' {
						$validColor = 'Green'
						$cautionColor = 'White'
					}
					'Palau' {
						$cautionColor = 'Yellow'
						$invalidColor = 'Blue'
					}
					'Palestine' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Panama' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Papua New Guinea' {
						$validColor = 'DarkGray'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Paraguay' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Peru' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Philippines' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
						$cautionColor = 'Yellow'
					}
					'Pitcairn Islands' {
						$validColor = 'Green'
						$validColor = 'DarkGray'
						$validColor = 'White'
						$invalidColor = 'Red'
						$invalidColor = 'Blue'
						$cautionColor = 'Brown'
						$cautionColor = 'Yellow'
					}
					'Poland' {
						$validColor = 'White'
						$invalidColor = 'Red'
					}
					'Portugal' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Qatar' {
						$validColor = 'DarkRed'
						$cautionColor = 'White'
					}
					'Republic Of The Congo' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Romania' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Russian Federation' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Rwanda' {
						$validColor = 'Green'
						$invalidColor = 'Cyan'
						$cautionColor = 'Yellow'
					}
					'Saint Kitts And Nevis' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Saint Lucia' {
						$validColor = 'DarkGray'
						$validColor = 'White'
						$invalidColor = 'Cyan'
						$cautionColor = 'Yellow'
					}
					'Saint Vincent And The Grenadines' {
						$validColor = 'Green'
						$invalidColor = 'Blue'
						$cautionColor = 'Yellow'
					}
					'Samoa' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'San Marino' {
						$validColor = 'White'
						$cautionColor = 'Cyan'
					}
					'Sao Tome And Principe' {
						$validColor = 'Green'
						$validColor = 'DarkGray'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Saudi Arabia' {
						$validColor = 'Green'
						$cautionColor = 'White'
					}
					'Senegal' {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Serbia' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Seychelles' {
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Sierra Leone' {
						$validColor = 'Green'
						$invalidColor = 'Blue'
						$cautionColor = 'White'
					}
					'Singapore' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Slovakia' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Slovenia' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$invalidColor = 'Blue'
						$cautionColor = 'DarkYellow'
						$cautionColor = 'White'
					}
					'Solomon Islands' {
						$validColor = 'Olive Green'
						$invalidColor = 'Blue'
						$cautionColor = 'Yellow'
					}
					'Somalia' {
						$invalidColor = 'Blue'
						$cautionColor = 'White'
					}
					'South Africa' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$invalidColor = 'Blue'
						$invalidColor = 'DarkYellow'
						$cautionColor = 'White'
					}
					'South Korea' {
						$validColor = 'White'
						$validColor = 'DarkGray'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'South Sudan' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Spain' {
						$invalidColor = 'Red'
						$invalidColor = 'DarkYellow'
					}
					'Sri Lanka' {
						$validColor = 'Green'
						$invalidColor = 'DarkRed'
						$cautionColor = 'DarkYellow'
					}
					'Sudan' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Suriname' {
						$validColor = 'DarkYellow'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Sweden' {
						$validColor = 'Blue'
						$invalidColor = 'DarkYellow'
					}
					'Switzerland' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Syrian Arab Republic' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Tajikistan' {
						$validColor = 'DarkYellow'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Tanzania, United Republic Of' {
						$validColor = 'Green'
						$validColor = 'DarkGray'
						$invalidColor = 'Blue'
						$cautionColor = 'Yellow'
					}
					'Thailand' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Togo' {
						$validColor = 'Green'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Tonga' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Trinidad And Tobago' {
						$validColor = 'DarkGray'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Tunisia' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Turkey' {
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Turkmenistan' {
						$validColor = 'Green'
						$cautionColor = 'White'
					}
					'Tuvalu' {
						$validColor = 'DarkBlue'
						$invalidColor = 'DarkYellow'
						$invalidColor = 'Red'
						$cautionColor = 'Cyan'
						$cautionColor = 'White'
					}
					'Uganda' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
						$cautionColor = 'Yellow'
					}
					'Ukraine' {
						$invalidColor = 'Blue'
						$invalidColor = 'DarkYellow'
					}
					'United Arab Emirates' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'United Kingdom' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'United States' {
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Blue'
					}
					'Uruguay' {
						$invalidColor = 'Blue'
						$cautionColor = 'White'
					}
					'Uzbekistan' {
						$validColor = 'Green'
						$invalidColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Vanuatu' {
						$validColor = 'DarkGray'
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Venezuela' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Vietnam' {
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Yemen' {
						$validColor = 'DarkGray'
						$invalidColor = 'Red'
						$cautionColor = 'White'
					}
					'Zambia' {
						$validColor = 'Green'
						$validColor = 'DarkGray'
						$invalidColor = 'Red'
						$cautionColor = 'DarkYellow'
					}
					'Zimbabwe' {
						$validColor = 'Green'
						$validColor = 'DarkGray'
						$validColor = 'White'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
					'Åland Islands' {
						$validColor = 'Blue'
						$invalidColor = 'Red'
						$cautionColor = 'DarkYellow'
					}
					Default {
						$validColor = 'Green'
						$invalidColor = 'Red'
						$cautionColor = 'Yellow'
					}
				}; #end Switch Chromatic

				#Get the PackageIdentifier out of the PR title, and alert if it matches the auth list.
				$PackageIdentifier = ''
				try {
					$PackageIdentifier = (($clip2 | Select-String 'PackageIdentifier')[0] -split ': ')[1]
				} catch {
					$PackageIdentifier = (Get-CleanClip $clip);
				}
				$AuthMatch = $AuthList.PackageIdentifier -match $PackageIdentifier
				if ($AuthMatch) {
					$AuthListLine = $AuthList | Where-Object { $_.PackageIdentifier -match $AuthMatch }
					$strictness = $AuthListLine.strictness | Sort-Object -Unique
					$AuthAccount = $AuthListLine.account | Sort-Object -Unique
					$strictColor = ''
					if ($strictness -eq 'must') {
						$strictColor = $invalidColor
					} else {
						$strictColor = $cautionColor
					}
					Write-Host -NoNewline ' = = = = = = Submitter '
					Write-Host -NoNewline -f $strictColor "$strictness"
					Write-Host -NoNewline ' match '
					Write-Host -NoNewline -f $strictColor "$AuthAccount"
					Write-Host ' = = = = = = '
				}

				$WinGetOutput = Search-WinGetManifest $PackageIdentifier

				$wgLine = ($WinGetOutput | Select-String " $PackageIdentifier ")
				try {
					try {
						[System.Version]$ManifestVersion = ($wgLine -replace '\s+', ' ' -split ' ')[-2]
					} catch {
						[string]$ManifestVersion = ($wgLine -replace '\s+', ' ' -split ' ')[-2]
					}
				} catch {
					$ManifestVersion = ''
				}

				$titlejoin = ($title -join ' ')
				if (($titlejoin -match 'Automatic deletion') -OR ($titlejoin -match 'Remove')) {
					$validColor, $invalidColor = $invalidColor, $validColor #Swapping variable values.
					$copyClip = $true
				}

				if ($PackageIdentifier -eq 'Added') {
					Write-Host -f $invalidColor "$timevar Error reading package identifier"
					$noRecord = $true
				} elseif ($WinGetOutput -eq 'No package found matching input criteria.') {
					if ($noNew) {
						$noRecord = $true
					} else {
						if ($title[-1] -match $hashPRRegex) {
							if ((Get-Command Validate-Package).name) {
								Validate-Package
							} else {
								Create-Sandbox ($title[-1] -replace '#', '')
							}
						}; #end if noNew
					}; #end if PackageIdentifier
					Write-Host -f $invalidColor $timevar ($PackageIdentifier) $WinGetOutput
				} elseif ($null -eq $prVersion -or '' -eq $prVersion) {
					$noRecord = $true
					Write-Host -f $invalidColor "$timevar Error reading PR version"
				} elseif ($ManifestVersion -eq 'Unknown') {
					Write-Host -f $invalidColor "$timevar Error reading WinGet version"
				} elseif ($ManifestVersion -eq 'input') {
					$noRecord = $true
					Write-Host $WinGetOutput
				} elseif ($null -eq $ManifestVersion) {
					Write-Host $WinGetOutput
				} elseif ($ManifestVersion -eq 'add-watermark') {
					$noRecord = $true
					Write-Host -f $invalidColor "$timevar Error reading package identifier"
				} elseif ($prVersion -gt $ManifestVersion) {
					Write-Host -f $validColor "$timevar $PackageIdentifier prVersion $prVersion is greater than ManifestVersion $ManifestVersion"
				} elseif ($prVersion -lt $ManifestVersion) {
					$outMsg = "$timevar $PackageIdentifier prVersion $prVersion is less than ManifestVersion $ManifestVersion"
					Write-Host -f $invalidColor $outMsg
					if ($copyClip) {
						$outMsg | clip
						$clip = $outMsg
						$oldclip = $outMsg
					}
				} elseif ($prVersion -eq $ManifestVersion) {
					Write-Host -f $cautionColor "$timevar $PackageIdentifier prVersion $prVersion is equal to ManifestVersion $ManifestVersion"
				} else {
					$WinGetOutput
				};
				$oldclip = $clip
				if ($noRecord -eq $false) {
					if ($clip.length -le 128) {
						$clip = $clip -join '' | Where-Object { $_ -match $hashPRRegex }
						#Write-Debug "Output $clip to $LogFile"
						$clip | Out-File $LogFile -Append
					} else {
						Write-Host -f $cautionColor "$timevar Item length greater than 128 characters."
					} ; #end if clip
				}; #end if noRecord
			}; #end if Compare-Object
		}; #end if clip
		Start-Sleep 1
	}
}

#Utility functions
#Extract package name from clipboard contents
Function Get-CleanClip {
	[CmdletBinding()]
	param(
		$out = (Get-Clipboard)
	)
	$out = $out -replace '_v', ' '
	$out = $out -join '' #removes accidental line breaks
	#$DebugPreference = 'Continue'
	$i = 0
	#Write-Debug "$i time: $out";$i++
	$out = $out -replace 'Add '
	$out = $out -replace 'Automatic deletion of '
	$out = $out -replace 'Automatic update of '
	$out = $out -replace 'Remove '
	$out = $out -replace 'Update '
	#Write-Debug "$i time: $out";$i++
	if ($out.contains(': ')) {
		$out = ($out -split ': ')[1]
	}
	#Write-Debug "$i time: $out";$i++

	$out = ($out -split ' ')[0]
	#Write-Debug "$i time: $out";$i++
	$out
}

#Minimize output for automation
Function Search-WinGetManifest ($term) {
	$out = WinGet search $term --disable-interactivity | Where-Object { $_ -notmatch 'Γûê' }
	return $out
}

#Terminates any current sandbox and makes a new one.
Function Create-Sandbox {
	param(
		[string]$PRNumber = (Get-Clipboard)
	)
	$FirstLetter = $PRNumber[0]
	if ($FirstLetter -eq '#') {
		[string]$PRNumber = $PRNumber[1..$PRNumber.length] -join ''
	}
	Get-Process *sandbox* | ForEach-Object { Stop-Process $_ }
	Get-Process *wingetautomator* | ForEach-Object { Stop-Process $_ }
	$version = '1.6.1573-preview'
	$process = "wingetautomator://install?pull_request_number=$PRNumber&winget_cli_version=v$version&watch=yes"
	Start-Process $process
}
