#Copyright 2023-2024 Microsoft Corporation
#Author: Stephen Gillie
#Title: PRWatcher v1.2.13
#Created: 2/15/2023
#Updated: 1/19/2024
#Notes: Streamlines WinGet-pkgs manifest PR moderator approval by watching the clipboard - copy a PR's FIles tab to your clipboard, and Get-PRWatch parse the PR, start a VM to review if new, and approve the PR if it passes all checks. Also outputs valid titles to a logging file. Freeing moderators to focus on approving and helping.
#Update log:
#1.2.13 Ignore removals when checking Apps and Features entries.
#1.2.12 Bugfix to file clobbering detection auto-reply.
#1.2.11 Make space detection auto-reply more robust.
#1.2.10 Change Invoke-GitHubPRRequest Silent output to be an Output option instead of a separate flag 
#1.2.9 Bugfix to Apps and Features detection. 



Function Get-PRWatch {
	[CmdletBinding()]
	param(
		[switch]$noNew,
		$LogFile = ".\PR.txt",
		$AuthFile = ".\Auth.csv",
		$ReviewFile = ".\Review.csv",
		[ValidateSet("Default","Warm","Cool","Random","Afghanistan","Albania","Algeria","American Samoa","Andorra","Angola","Anguilla","Antigua And Barbuda","Argentina","Armenia","Aruba","Australia","Austria","Azerbaijan","Bahamas","Bahrain","Bangladesh","Barbados","Belarus","Belgium","Belize","Benin","Bermuda","Bhutan","Bolivia","Bosnia And Herzegovina","Botswana","Bouvet Island","Brazil","Brunei Darussalam","Bulgaria","Burkina Faso","Burundi","Cabo Verde","Cambodia","Cameroon","Canada","Central African Republic","Chad","Chile","China","Colombia","Comoros","Cook Islands","Costa Rica","Croatia","Cuba","Curacao","Cyprus","Czechia","Cöte D'Ivoire","Democratic Republic Of The Congo","Denmark","Djibouti","Dominica","Dominican Republic","Ecuador","Egypt","El Salvador","Equatorial Guinea","Eritrea","Estonia","Eswatini","Ethiopia","Fiji","Finland","France","French Polynesia","Gabon","Gambia","Georgia","Germany","Ghana","Greece","Grenada","Guatemala","Guinea","Guinea-Bissau","Guyana","Haiti","Holy See (Vatican City State)","Honduras","Hungary","Iceland","India","Indonesia","Iran","Iraq","Ireland","Israel","Italy","Jamaica","Japan","Jordan","Kazakhstan","Kenya","Kiribati","Kuwait","Kyrgyzstan","Laos","Latvia","Lebanon","Lesotho","Liberia","Libya","Liechtenstein","Lithuania","Luxembourg","Madagascar","Malawi","Malaysia","Maldives","Mali","Malta","Marshall Islands","Mauritania","Mauritius","Mexico","Micronesia","Moldova","Monaco","Mongolia","Montenegro","Morocco","Mozambique","Myanmar","Namibia","Nauru","Nepal","Netherlands","New Zealand","Nicaragua","Niger","Nigeria","Niue","Norfolk Island","North Korea","North Macedonia","Norway","Oman","Pakistan","Palau","Palestine","Panama","Papua New Guinea","Paraguay","Peru","Philippines","Pitcairn Islands","Poland","Portugal","Qatar","Republic Of The Congo","Romania","Russian Federation","Rwanda","Saint Kitts And Nevis","Saint Lucia","Saint Vincent And The Grenadines","Samoa","San Marino","Sao Tome And Principe","Saudi Arabia","Senegal","Serbia","Seychelles","Sierra Leone","Singapore","Slovakia","Slovenia","Solomon Islands","Somalia","South Africa","South Korea","South Sudan","Spain","Sri Lanka","Sudan","Suriname","Sweden","Switzerland","Syrian Arab Republic","Tajikistan","Tanzania, United Republic Of","Thailand","Togo","Tonga","Trinidad And Tobago","Tunisia","Turkey","Turkmenistan","Tuvalu","Uganda","Ukraine","United Arab Emirates","United Kingdom","United States","Uruguay","Uzbekistan","Vanuatu","Venezuela","Vietnam","Yemen","Zambia","Zimbabwe","Åland Islands")]$Chromatic = "Default",
		$oldclip = "",
		$hashPRRegex = "[#][0-9]{5,6}",
		$AuthList = "",
		$ReviewList = ""
	)

	if (Test-Path $AuthFile) {
		$AuthList = Get-Content $AuthFile | ConvertFrom-Csv
		Write-Host "Using Auth file $AuthFile" -f green
	} else {
		Write-Host "Auth file $AuthFile not found!" -f red
	}
	Write-Host "Loaded $($AuthList.count) Auth file entries."

	if (Test-Path $ReviewFile) {
		$ReviewList = Get-Content $ReviewFile | ConvertFrom-Csv
		Write-Host "Using Review file $ReviewFile" -f green
	} else {
		Write-Host "Review file $ReviewFile not found!" -f red
	}
	Write-Host "Loaded $($ReviewFile.count) Review file entries."
	Write-Host " - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
	Write-Host "| Timestmp | $(Get-PadRight PR# 6) | $(Get-PadRight PackageIdentifier) | $(Get-PadRight prVersion 14) | A | R | W | F | I | D | $(Get-PadRight ManifestVer 14)  | OK |"

	if ((Get-Command Get-TrackerVMSetMode).name) {Get-TrackerVMSetMode "Approving"}
	while($true){
		$clip = (Get-Clipboard)
		$PRtitle = $clip | select-string "[#][0-9]{5,6}$";
		$PR = ($PRtitle -split "#")[1]
		if ($PRtitle) {
			if (Compare-Object $PRtitle $oldclip) {
				if ((Get-Command Get-Status).name) {
					(Get-Status | Where-Object {$_.status -eq "ValidationComplete"} | Format-Table)
				}
				$validColor = "green"
				$invalidColor = "red"
				$cautionColor = "yellow"

				Switch ($Chromatic) {
					#Color schemes, to accomodate needs and also add variety.
						"Default" {
							$validColor = "Green"
							$invalidColor = "Red"
							$cautionColor = "Yellow"
						}
						"Warm" {
							$validColor = "White"
							$invalidColor = "Red"
							$cautionColor = "Yellow"
						}
						"Cool" {
							$validColor = "Green"
							$invalidColor = "Blue"
							$cautionColor = "Cyan"
						}
						"Random" {
							$Chromatic = ($CountrySet | get-random)
							Write-Host "Using CountrySet $Chromatic" -f green
						}
#https://www.flagpictures.com/countries/flag-colors/
"Afghanistan"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Albania"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
}
"Algeria"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"American Samoa"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Andorra"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Angola"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Anguilla"{
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Antigua And Barbuda"{
	$invalidColor = "Red"
	$validColor = "DarkGray"
	$invalidColor = "Blue"
	$validColor = "White"
	$cautionColor = "Yellow"
}
"Argentina"{
	$validColor = "White"
	$cautionColor = "Cyan"
}
"Armenia"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
"Aruba"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Australia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Austria"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Azerbaijan"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Cyan"
}
"Bahamas"{
	$validColor = "DarkGray"
	$invalidColor = "Cyan"
	$cautionColor = "Yellow"
}
"Bahrain"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Bangladesh"{
	$validColor = "Green"
	$invalidColor = "Red"
}
"Barbados"{
	$validColor = "DarkGray"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
}
"Belarus"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Belgium"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Belize"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Benin"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Bermuda"{
	$invalidColor = "Red"
}
"Bhutan"{
	$validColor = "DarkRed"
	$invalidColor = "DarkYellow"
	$cautionColor = "White"
}
"Bolivia"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Bosnia And Herzegovina"{
	$invalidColor = "Blue"
	$validColor = "White"
	$cautionColor = "Yellow"
}
"Botswana"{
	$validColor = "DarkGray"
	$invalidColor = "White"
	$cautionColor = "Cyan"
}
"Bouvet Island"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Brazil"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
}
"Brunei Darussalam"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$validColor = "White"
	$cautionColor = "Yellow"
}
"Bulgaria"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Burkina Faso"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Burundi"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Cabo Verde"{
	$validColor = "White"
	$invalidColor = "DarkYellow"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Cambodia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Cameroon"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Canada"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Central African Republic"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
	$cautionColor = "Yellow"
}
"Chad"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Chile"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"China"{
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
"Colombia"{
	$invalidColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Comoros"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
	$cautionColor = "Yellow"
}
"Cook Islands"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Costa Rica"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Croatia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Cuba"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Curaçao"{
	$validColor = "White"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Cyprus"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"Czechia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Côte D'Ivoire"{
	$validColor = "Green"
	$invalidColor = "DarkYellow"
	$cautionColor = "White"
}
"Democratic Republic Of The Congo"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Denmark"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Djibouti"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Cyan"
}
"Dominica"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Dominican Republic"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Ecuador"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Egypt"{
	$validColor = "DarkGray"
	$invalidColor = "DarkYellow"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"El Salvador"{
	$validColor = "White"
	$invalidColor = "DarkYellow"
	$cautionColor = "Blue"
}
"Equatorial Guinea"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Eritrea"{
	$validColor = "Green"
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Estonia"{
	$validColor = "DarkGray"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Eswatini"{
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
	$cautionColor = "Yellow"
}
"Ethiopia"{
	$validColor = "Green"
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Fiji"{
	$validColor = "White"
	$validColor = "DarkBlue"
	$invalidColor = "DarkYellow"
	$invalidColor = "Red"
	$cautionColor = "Cyan"
}
"Finland"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"France"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"French Polynesia"{
	$validColor = "White"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
}
"Gabon"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Gambia"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Georgia"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Germany"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
"Ghana"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Greece"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"Grenada"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Guatemala"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"Guinea"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Guinea-Bissau"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Guyana"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Haiti"{
	$validColor = "Blue"
	$invalidColor = "Red"
}
"Holy See (Vatican City State)"{
	$validColor = "White"
	$cautionColor = "Yellow"
}
"Honduras"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"Hong Kong" {
	$validColor = "White"
	$invalidColor = "Red"
}
"Hungary"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Iceland"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"India"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
}
"Indonesia"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Iran"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Iraq"{
	$invalidColor = "Red"
	$validColor = "DarkGray"
	$validColor = "Green"
	$cautionColor = "White"
}
"Ireland"{
	$validColor = "Green"
	$invalidColor = "Blue"
}
"Israel"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"Italy"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Jamaica"{
	$validColor = "Green"
	$invalidColor = "DarkGray"
	$cautionColor = "DarkYellow"
}
"Japan"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Jordan"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Kazakhstan"{
	$cautionColor = "Yellow"
	$invalidColor = "Blue"
}
"Kenya"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Kiribati"{
	$validColor = "White"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
}
"Kuwait"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Kyrgyzstan"{
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Laos"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Latvia"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Lebanon"{
	$invalidColor = "Red"
	$validColor = "Green"
	$cautionColor = "White"
}
"Lesotho"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Liberia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Libya"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Liechtenstein"{
	$validColor = "Blue"
	$invalidColor = "Red"
}
"Lithuania"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Luxembourg"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Cyan"
}
"Macao" {
	$validColor = "Green"
	$cautionColor = "White"
}
"Madagascar"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Malawi"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "DarkGray"
}
"Malaysia"{
	$validColor = "White"
	$invalidColor = "Red"
	$invalidColor = "DarkBlue"
	$cautionColor = "Yellow"
}
"Maldives"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Mali"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Malta"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Marshall Islands"{
	$invalidColor = "Blue"
	$invalidColor = "DarkYellow"
	$cautionColor = "White"
}
"Mauritania"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Mauritius"{
	$validColor = "Green"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Mexico"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Micronesia"{
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Moldova"{
	$validColor = "Blue"
	$invalidColor = "DarkYellow"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Monaco"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Mongolia"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Montenegro"{
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
"Morocco"{
	$validColor = "Green"
	$invalidColor = "Red"
}
"Mozambique"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Myanmar"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
	$cautionColor = "White"
}
"Namibia"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Nauru"{
	$invalidColor = "Blue"
	$validColor = "White"
	$cautionColor = "Yellow"
}
"Nepal"{
	$validColor = "DarkRed"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Netherlands"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"New Zealand"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Nicaragua"{
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Niger"{
	$validColor = "Green"
	$cautionColor = "White"
	$cautionColor = "DarkYellow"
}
"Nigeria"{
	$validColor = "Green"
	$cautionColor = "White"
}
"Niue"{
	$validColor = "DarkYellow"
}
"Norfolk Island"{
	$validColor = "Green"
	$cautionColor = "White"
}
"North Korea"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"North Macedonia"{
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Norway"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Oman"{
	$invalidColor = "Red"
	$validColor = "Green"
	$cautionColor = "White"
}
"Pakistan"{
	$validColor = "Green"
	$cautionColor = "White"
}
"Palau"{
	$cautionColor = "Yellow"
	$invalidColor = "Blue"
}
"Palestine"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Panama"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Papua New Guinea"{
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Paraguay"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Peru"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Philippines"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
	$cautionColor = "Yellow"
}
"Pitcairn Islands"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "Brown"
	$cautionColor = "Yellow"
}
"Poland"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Portugal"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Qatar"{
	$validColor = "DarkRed"
	$cautionColor = "White"
}
"Republic Of The Congo"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Romania"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Russian Federation"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Rwanda"{
	$validColor = "Green"
	$invalidColor = "Cyan"
	$cautionColor = "Yellow"
}
"Saint Kitts And Nevis"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Saint Lucia"{
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Cyan"
	$cautionColor = "Yellow"
}
"Saint Vincent And The Grenadines"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Samoa"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"San Marino"{
	$validColor = "White"
	$cautionColor = "Cyan"
}
"Sao Tome And Principe"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Saudi Arabia"{
	$validColor = "Green"
	$cautionColor = "White"
}
"Senegal"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Serbia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Seychelles"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Sierra Leone"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Singapore"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Slovakia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Slovenia"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
	$cautionColor = "White"
}
"Solomon Islands"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Somalia"{
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"South Africa"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$invalidColor = "DarkYellow"
	$cautionColor = "White"
}
"South Korea"{
	$validColor = "White"
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"South Sudan"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Spain"{
	$invalidColor = "Red"
	$invalidColor = "DarkYellow"
}
"Sri Lanka"{
	$validColor = "Green"
	$invalidColor = "DarkRed"
	$cautionColor = "DarkYellow"
}
"Sudan"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Suriname"{
	$validColor = "DarkYellow"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Sweden"{
	$validColor = "Blue"
	$invalidColor = "DarkYellow"
}
"Switzerland"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Syrian Arab Republic"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Tajikistan"{
	$validColor = "DarkYellow"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Tanzania, United Republic Of"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Thailand"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Togo"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Tonga"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Trinidad And Tobago"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Tunisia"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Turkey"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Turkmenistan"{
	$validColor = "Green"
	$cautionColor = "White"
}
"Tuvalu"{
	$validColor = "DarkBlue"
	$invalidColor = "DarkYellow"
	$invalidColor = "Red"
	$cautionColor = "Cyan"
	$cautionColor = "White"
}
"Uganda"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
	$cautionColor = "Yellow"
}
"Ukraine"{
	$invalidColor = "Blue"
	$invalidColor = "DarkYellow"
}
"United Arab Emirates"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"United Kingdom"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"United States"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Uruguay"{
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Uzbekistan"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Vanuatu"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Venezuela"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Vietnam"{
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Yemen"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Zambia"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
"Zimbabwe"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Åland Islands"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
						Default {
							$validColor = "Green"
							$invalidColor = "Red"
							$cautionColor = "Yellow"
						}
					}; #end Switch Chromatic

				$noRecord = $false
				$title = $PRtitle -split ": "
				if ($title[1]) {
					$title = $title[1] -split " "
				} else {
					$title = $title -split " "
				}
				$Submitter = (($clip | select-string "wants to merge") -split " ")[0]

				#Split the title by spaces. Try extracting the version location as the next item after the word "version", and if that fails, use the 2nd to the last item, then 3rd to last, and 4th to last. For some reason almost everyone puts the version number as the last item, and GitHub appends the PR number.
				$prVerLoc =($title | Select-String "version").linenumber
				#Version is on the line before the line number, and this set indexes with 1 - but the following array indexes with 0, so the value is automatically transformed by the index mismatch.
				try {
					[System.Version]$prVersion = Get-YamlValue PackageVersion $clip -replace "'","" -replace '"',''
				} catch {
					try {
						$prVersion = Get-YamlValue PackageVersion $clip -replace "'","" -replace '"',''
					} catch {
							try {
						[System.Version]$prVersion = Get-YamlValue PackageVersion $clip
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
				}; #end try

				#Get the PackageIdentifier and alert if it matches the auth list.
				$PackageIdentifier = ""
				try {
					$PackageIdentifier = Get-YamlValue PackageIdentifier $clip -replace '"',""
				} catch {
					$PackageIdentifier = (Get-CleanClip $PRtitle); -replace '"',""
				}
				$matchColor = $validColor

				Write-Host -nonewline -f $matchColor "| $(get-date -Format T) | $PR | $(Get-PadRight $PackageIdentifier) | "

				#Variable effervescence
				$prAuth = "+"
				$Auth = "A"
				$Review = "R"
				$WordFilter = "W"
				$AnF = "F"
				$InstVer = "I"
				$ListingDiff = "D"
				$PRvMan = "P"
				$Approve = "+"

				$WinGetOutput = Find-WinGetPackage $PackageIdentifier | Where-Object {$_.id -eq $PackageIdentifier}
				$ManifestVersion = $WinGetOutput.version
				$ManifestVersionParams = ($ManifestVersion -split "[.]").count
				$prVersionParams = ($prVersion -split "[.]").count


				if ($null -eq $WinGetOutput) {
					$PRvMan = "N"
					$matchColor = $invalidColor
					$Approve = "-!"
					if ($noNew) {
						$noRecord = $true
					} else {
						if ($title[-1] -match $hashPRRegex) {
							if ((Get-Command Get-TrackerVMValidate).name) {
								Get-TrackerVMValidate -Silent -InspectNew
							} else {
								Get-Sandbox ($title[-1] -replace"#","")
							}; #end if Get-Command
						}; #end if title
					}; #end if noNew
				} elseif ($null -ne $WinGetOutput) {
					If ($PRtitle -match " [.]") {
					#If has spaces (4.4 .5 .220)
						$Body = "Spaces detected in version number."
						$Body = $Body + "`n`n(Automated response - build $build)"
						Reply-ToPR -PR $PR -Body $Body -Silent
						$matchColor = $invalidColor
						$prAuth = "-!"
					}
					if ($ManifestVersionParams -ne $prVersionParams) {
						$greaterOrLessThan = ""
						if ($prVersionParams -lt $ManifestVersionParams) {
							#If current manifest has more params (dots) than PR (2.3.4.500 to 2.3.4)
							$greaterOrLessThan = "less"
						} elseif ($prVersionParams -gt $ManifestVersionParams) {
							#If current manifest has fewer params (dots) than PR (2.14 to 2.14.3.222)
							$greaterOrLessThan = "greater"
						}
						$matchColor = $invalidColor
						$Approve = "-!"
						$Body = "Hi @$Submitter,`n`n> This PR's version number $prVersion has $prVersionParams parameters (sets of numbers between dots - major, minor, etc), which is $greaterOrLessThan than the current manifest's version $($ManifestVersion), which has $ManifestVersionParams parameters.`n`nIs this intentional?"
						$Body = $Body + "`n`n(Automated response - build $build)"
						Reply-ToPR -PR $PR -Body $Body -Silent 
						Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Needs-Author-Feedback" -Output Silent
						Add-PRToRecord $PR "Feedback"
					}
				}


				Write-Host -nonewline -f $matchColor "$(Get-PadRight $prVersion.toString() 14) | "
				$matchColor = $validColor

				$AuthMatch = $AuthList | Where-Object {$_.PackageIdentifier -match (($PackageIdentifier -split "[.]")[0..1] -join ".")}

				if ($AuthMatch) {
					$strictness = $AuthMatch.strictness | Sort-Object -Unique
					$AuthAccount = $AuthMatch.account | Sort-Object -Unique

					$matchVar = ""
					$matchColor = $cautionColor
					if ($AuthAccount -cmatch $Submitter) {
						$matchVar = "matches"
						$Auth = "+"
						$matchColor = $validColor
					} else {
						$matchVar = "does not match"
						$Auth = "-"
						$matchColor = $invalidColor
					}

					if ($strictness -eq "must") {
						$Auth += "!"
					} else {
					}
				}
				if ($Auth -eq "-!") {
						Get-PRApproval -PR $PR -PackageIdentifier $PackageIdentifier
				}


				Write-Host -nonewline -f $matchColor "$Auth | "
				$matchColor = $validColor



				$ReviewMatch = $ReviewList | Where-Object {$_.PackageIdentifier -match (($PackageIdentifier -split "[.]")[0..1] -join ".")}

				if ($ReviewMatch) {
					$Review = $ReviewMatch.Reason | Sort-Object -Unique
					$matchColor = $cautionColor
				}
				Write-Host -nonewline -f $matchColor "$Review | "
				$matchColor = $validColor

				#$WordFilterList = @(".bat", ".ps1", ".cmd","accept_gdpr ", "accept-licenses", "accept-license","eula")
				$WordFilterList = @("accept_gdpr ", "accept-licenses", "accept-license","eula")
				$WordFilterMatch = $WordFilterList | ForEach-Object {($Clip -match $_) -notmatch "Url"}

				if ($WordFilterMatch) {
					$WordFilter = "-!"
					$Approved = "-!"
					$matchColor = $invalidColor
					Reply-ToPR -PR $PR -CannedResponse WordFilter -UserInput $WordFilterMatch -Silent
				}
				Write-Host -nonewline -f $matchColor "$WordFilter | "
				$matchColor = $validColor
				

				if ($null -ne $WinGetOutput) {
					if (($PRvMan -ne "N") -AND (($PRtitle -notmatch "Automatic deletion") -AND ($PRtitle -notmatch "Remove"))) {
						$ANFOld = Get-ManifestEntryCheck -PackageIdentifier $PackageIdentifier -Version $ManifestVersion
						$ANFCurrent = [bool]($clip | Select-String "AppsAndFeaturesEntries")

						if (($ANFOld -eq $true) -and ($ANFCurrent -eq $false)) {
							$matchColor = $invalidColor
							$AnF = "-"
							Reply-ToPR -PR $PR -CannedResponse AppsAndFeaturesMissing -UserInput $Submitter -Silent
							Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Needs-Author-Feedback" -Output Silent
							Add-PRToRecord $PR "Feedback"
						} elseif (($ANFOld -eq $false) -and ($ANFCurrent -eq $true)) {
							$matchColor = $cautionColor
							$AnF = "+"
							Reply-ToPR -PR $PR -CannedResponse AppsAndFeaturesNew -UserInput $Submitter -Silent
							#Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Needs-Author-Feedback"
						} elseif (($ANFOld -eq $false) -and ($ANFCurrent -eq $false)) {
							$AnF = "0"
						} elseif (($ANFOld -eq $true) -and ($ANFCurrent -eq $true)) {
							$AnF = "1"
						}
					}
				}
				Write-Host -nonewline -f $matchColor "$AnF | "
				$matchColor = $validColor


				if (($PRvMan -ne "N") -OR ($PRtitle -notmatch "Automatic deletion") -OR ($PRtitle -notmatch "Remove")) {
					try {
						if ([bool]($clip -match "InstallerUrl")) {
							$InstallerUrl = Get-YamlValue InstallerUrl -clip $clip
							#write-host "InstallerUrl: $InstallerUrl $installerMatches prVersion: $prVersion" -f "blue"
							$installerMatches = [bool]($InstallerUrl | select-string $prVersion)
							if (!($installerMatches)) {
								#Matches when the dots are removed from semantec versions in the URL.
								$installerMatches2 = [bool]($InstallerUrl | select-string ($prVersion -replace "[.]",""))
								if (!($installerMatches2)) {
									$matchColor = $invalidColor
									$InstVer = "-"
								}
							}
						}
					} catch {
						$matchColor = $invalidColor
						$InstVer = "-"
					}; #end try
				}; #end if PRvMan

				try {
				if (($prVersion = Get-YamlValue PackageVersion $clip) -match " ") {
					$matchColor = $invalidColor
					$InstVer = "-!"
				}
				}catch{
					$null = (Get-Process) #This section intentionally left blank.
				}

				Write-Host -nonewline -f $matchColor "$InstVer | "
				$matchColor = $validColor

				$GLD = (Get-ListingDiff $clip | Where-Object {$_.SideIndicator -eq "<="}).installer.yaml #Ignores when a PR adds files that didn't exist before.
				if ($GLD -ne $null) {
					if ($GLD -eq "Error") {
						$ListingDiff = "E"
						$matchColor = $invalidColor
					} else {

						$ListingDiff = "-!"
						$matchColor = $cautionColor
						Reply-ToPR -PR $PR -CannedResponse ListingDiff -UserInput $GLD -Silent
						Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Needs-Author-Feedback" -Output Silent
						Add-PRToRecord $PR "Feedback"
					}
				}
				Write-Host -nonewline -f $matchColor "$ListingDiff | "
				$matchColor = $validColor

				if (($PRtitle -match "Automatic deletion") -OR ($PRtitle -match "Remove")) {
					#$validColor,$invalidColor = $invalidColor,$validColor #Swapping variable values.
				}

				if ($PRvMan -ne "N") {
					if ($null -eq $prVersion -or "" -eq $prVersion) {
						$noRecord = $true
						$PRvMan = "Error:prVersion"
						$matchColor = $invalidColor
					} elseif ($ManifestVersion -eq "Unknown") {
						$noRecord = $true
						$PRvMan = "Error:ManifestVersion"
						$matchColor = $invalidColor
					} elseif ($null -eq $ManifestVersion) {
						$noRecord = $true
						$PRvMan =  $WinGetOutput
						$matchColor = $invalidColor
					} elseif ($prVersion -gt $ManifestVersion) {
						$PRvMan = $ManifestVersion.toString()
					} elseif ($prVersion -lt $ManifestVersion) {
						$PRvMan = $ManifestVersion.toString()
						$matchColor = $cautionColor
					} elseif ($prVersion -eq $ManifestVersion) {
						$PRvMan = "="
					} else {
						$noRecord = $true
						$PRvMan =  $WinGetOutput
					};
				};


				if (($Approve -eq "-!") -or ($Auth -eq "-!") -or ($AnF -eq "-") -or ($InstVer -eq "-!") -or ($prAuth -eq "-!") -or ($ListingDiff -eq "-!") -or ($WordFilter -eq "-!") -or ($PRvMan -eq "N")) {
				#-or ($PRvMan -match "^Error")
					$matchColor = $cautionColor
					$Approve = "-!"
					$noRecord = $true
				}

				$PRvMan = Get-PadRight $PRvMan 14
				Write-Host -nonewline -f $matchColor "$PRvMan | "
				$matchColor = $validColor

				if ($Approve -eq "+") {
					$Approve = Approve-PR $PR
					Add-PRToRecord $PR Approved
				}

				Write-Host -nonewline -f $matchColor "$Approve | "
				Write-Host -f $matchColor ""

				$oldclip = $PRtitle
			}; #end if Compare-Object
		}; #end if clip
		Start-Sleep 1
	}; #end if PRtitle
}; #end function

#Utility functions
#Extract package name from clipboard contents
Function Get-CleanClip {
	[CmdletBinding()]
	param(
		$out = (Get-Clipboard)
	)
	$out = $out -replace "_v"," "
	$out = $out -join "" #removes accidental line breaks
	$out =  $out -replace "Add "
	$out =  $out -replace "Automatic deletion of "
	$out =  $out -replace "Automatic update of "
	$out =  $out -replace "Remove "
	$out =  $out -replace "Update "
	if ($out.contains(": ")) {
		$out =  ($out -split ": ")[1]
	}

	$out =  ($out -split " ")[0]
	$out
}

#Terminates any current sandbox and makes a new one.
Function Get-Sandbox {
	param(
		[string]$PRNumber = (Get-Clipboard)
	)
	$FirstLetter = $PRNumber[0]
	if ($FirstLetter -eq "#") {
		[string]$PRNumber = $PRNumber[1..$PRNumber.length] -join ""
	}
	Get-Process *sandbox* | ForEach-Object {Stop-Process $_}
	Get-Process *wingetautomator* | ForEach-Object {Stop-Process $_}
	$version = "1.6.1573-preview"
	$process ="wingetautomator://install?pull_request_number=$PRNumber&winget_cli_version=v$version&watch=yes"
	Start-Process $process
}

Function Get-ManifestEntryCheck {
	param(
		$PackageIdentifier,
		$Version,
		$Entry = "AppsAndFeaturesEntries"
	)
	$content = Get-WinGetFile $PackageIdentifier $Version
	$out = ($content | Where-Object {$_ -match $Entry})
	if ($out) {$true} else {$false}
}

Function Get-PadRight {
	param(
	[string]$PackageIdentifier,
	[int]$PadChars = 32
	)
	$out = $PackageIdentifier
	if ($PackageIdentifier.Length -lt $PadChars) {
		$out = $PackageIdentifier +(" "*($PadChars - $PackageIdentifier.Length -1))
	} elseif ($PackageIdentifier.Length -lt $PadChars) {
		$out = $PackageIdentifier[0..($PadChars -1)]
	}

	if ($out.GetType().name -eq "Array") {

	}
	$out = $out -join ""

	$out
}

$CountrySet = "Default","Warm","Cool","Random","Afghanistan","Albania","Algeria","American Samoa","Andorra","Angola","Anguilla","Antigua And Barbuda","Argentina","Armenia","Aruba","Australia","Austria","Azerbaijan","Bahamas","Bahrain","Bangladesh","Barbados","Belarus","Belgium","Belize","Benin","Bermuda","Bhutan","Bolivia","Bosnia And Herzegovina","Botswana","Bouvet Island","Brazil","Brunei Darussalam","Bulgaria","Burkina Faso","Burundi","Cabo Verde","Cambodia","Cameroon","Canada","Central African Republic","Chad","Chile","China","Colombia","Comoros","Cook Islands","Costa Rica","Croatia","Cuba","Curacao","Cyprus","Czechia","Cöte D'Ivoire","Democratic Republic Of The Congo","Denmark","Djibouti","Dominica","Dominican Republic","Ecuador","Egypt","El Salvador","Equatorial Guinea","Eritrea","Estonia","Eswatini","Ethiopia","Fiji","Finland","France","French Polynesia","Gabon","Gambia","Georgia","Germany","Ghana","Greece","Grenada","Guatemala","Guinea","Guinea-Bissau","Guyana","Haiti","Holy See (Vatican City State)","Honduras","Hungary","Iceland","India","Indonesia","Iran","Iraq","Ireland","Israel","Italy","Jamaica","Japan","Jordan","Kazakhstan","Kenya","Kiribati","Kuwait","Kyrgyzstan","Laos","Latvia","Lebanon","Lesotho","Liberia","Libya","Liechtenstein","Lithuania","Luxembourg","Madagascar","Malawi","Malaysia","Maldives","Mali","Malta","Marshall Islands","Mauritania","Mauritius","Mexico","Micronesia","Moldova","Monaco","Mongolia","Montenegro","Morocco","Mozambique","Myanmar","Namibia","Nauru","Nepal","Netherlands","New Zealand","Nicaragua","Niger","Nigeria","Niue","Norfolk Island","North Korea","North Macedonia","Norway","Oman","Pakistan","Palau","Palestine","Panama","Papua New Guinea","Paraguay","Peru","Philippines","Pitcairn Islands","Poland","Portugal","Qatar","Republic Of The Congo","Romania","Russian Federation","Rwanda","Saint Kitts And Nevis","Saint Lucia","Saint Vincent And The Grenadines","Samoa","San Marino","Sao Tome And Principe","Saudi Arabia","Senegal","Serbia","Seychelles","Sierra Leone","Singapore","Slovakia","Slovenia","Solomon Islands","Somalia","South Africa","South Korea","South Sudan","Spain","Sri Lanka","Sudan","Suriname","Sweden","Switzerland","Syrian Arab Republic","Tajikistan","Tanzania"," United Republic Of","Thailand","Togo","Tonga","Trinidad And Tobago","Tunisia","Turkey","Turkmenistan","Tuvalu","Uganda","Ukraine","United Arab Emirates","United Kingdom","United States","Uruguay","Uzbekistan","Vanuatu","Venezuela","Vietnam","Yemen","Zambia","Zimbabwe","Åland Islands"
