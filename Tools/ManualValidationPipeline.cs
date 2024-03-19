//Copyright 2022-2024 Microsoft Corporation
//Author: Stephen Gillie
//Title: WinGet Approval Pipeline v3.-62.2
//Created: 1/19/2024
//Updated: 3/15/2024
//Notes: Tool to streamline evaluating winget-pkgs PRs.
//Update log:
//3.-62.2 - Rename YamlValue variables to be more clear.
//3.-62.1 - Bugfix not detecting PR number from URL.
//3.-62.1 - Bugfix try/catch UEs from Status file being blocked by VM writes.
//3.-62.0 - Port OSFromVersion.
//3.-63.0 - Depreciate Timeclock section.
//3.-67.1 - Move GitHubToken load from custom function to GetContent.
//3.-67.0 - Depreciate LoadFileIfExists.
//3.-68.0 - Depreciate RotateLog.






/*Contents: (Remaining functions to port or depreciate: 56)
- Init vars (?)
- Boilerplate (?)
- UI top-of-box (?)
	- Menu (?)
- Tabs (3)
- Automation Tools (5)
- PR tools (2)
- Network tools (0)
- Validation Starts Here (6)
- Manifests Etc (5)
- VM Image Management (3)
- VM Pipeline Management (6)
- VM Status (2)
- VM Versioning (1)
- VM Orchestration (4)
- File Management (1)
- Inject into files on disk (2)
- Inject into PRs (4)
- Reporting (2)
- Clipboard (3)
- Etc (2)
- PR Watcher Utility functions (1)
- Powershell equivalency (+8)
- VM Window management (3)
- Misc data (+5)

Et cetera:
- UserInput field 
- Mode through button effects
- VM control buttons
- PR counters on certain buttons - Approval-Ready, ToWork, Defender, IEDS
- Better way to display VM/Validation lists.
- CLI switches such as --hourly-run
*/






/*
Partial (5): 
CheckStandardPRComments needs work on data structures. 
PRInstallerStatusInnerWrapper might be unnecessary.
Get-TrackerVMWindowLoc
Get-TrackerVMWindowSet
Get-TrackerVMWindowArrange#Get-TrackerVMWindowSet, Get-TrackerVMWindowLoc
PadRight
PRStateFromComments
LineFromCommitFile

#Todo: 
Test-Admin
Get-PRApproval
Add-ToValidationFile
Get-PRFromRecord
Add-DependencyToPR
Get-UpdateArchInPR
Get-UpdateHashInPR
Get-UpdateHashInPR2

#Blocked:
Get-ManifestListing#Find-WinGetPackage
Get-ConnectedVM#Test-Admin
Add-InstallerSwitch#Add-ToValidationFile
Open-AllURL#Start-Process
Open-PRInBrowser#Start-Process
Get-ListingDiff#Get-ManifestListing
Get-TrackerVMRebuildStatus#Get-VM
Get-PRReportFromRecord#Get-PRFromRecord
Get-PRFullReport#Get-PRReportFromRecord
Get-TrackerVMValidateByID#Get-TrackerVMValidate
Get-TrackerVMValidateByConfig#Get-TrackerVMValidate
Get-TrackerVMValidateByArch#Get-TrackerVMValidate
Get-TrackerVMValidateByScope#Get-TrackerVMValidate
Get-TrackerVMValidateBothArchAndScope#Get-TrackerVMValidate

Get-SearchGitHub#Get-Date, Start-Process
Get-ManifestAutomation#Get-ManifestFile, Get-NextFreeVM
Stop-TrackerVM#Stop-VM, Test-Admin
Get-TrackerVMRotateLog#Get-Date, Move-Item
Get-SingleFileAutomation#Get-ManifestFile, Get-ManifestListing
Get-Sandbox#Stop-Process, Start-Process
Get-NextFreeVM#Get-Random, Test-Admin
Get-RemoveFileIfExist#New-Item, Remove-Item
Get-TrackerVMRevert#Restore-VMCheckpoint, Test-Admin
Get-TrackerVMResetStatus#Get-ConnectedVM, Stop-Process
Get-TrackerVMRotate#Get-Random, Get-TrackerVMVersion

Get-TrackerVMLaunchWindow#Get-ConnectedVM, Stop-Process, Test-Admin 
Get-ManifestFile#Get-NextFreeVM, Get-RemoveFileIfExist, Get-TrackerVMValidate

Redo-Checkpoint#Checkpoint-VM, Redo-Checkpoint, Remove-VMCheckpoint, Test-Admin
Get-RandomIEDS#Get-ManifestFile, Get-NextFreeVM, Get-Random, Get-SearchGitHub
Get-ImageVMStart#Get-TrackerVMLaunchWindow, Get-TrackerVMRevert, Start-VM, Test-Admin

Get-TrackerVMRunTracker#Get-AutoValLog, Get-ConnectedVM, Get-Date, Get-HoursWorkedToday, Get-PRLabelAction, Get-Random, Get-RandomIEDS, Get-SearchGitHub, Get-TrackerMode, Get-TrackerVMCycle, Get-TrackerVMRotate, Get-TrackerVMValidate, Get-TrackerVMWindowArrange, Get-VM, Set-Vm, start-process
Get-PRWatch#Approve-PR, Compare-Object, Find-WinGetPackage, Get-CleanClip, Get-Command, Get-Date, Get-ListingDiff, Get-PadRight, Get-PRApproval, Get-Random, Get-Sandbox, Get-TrackerVMValidate
Get-WorkSearch#Get-Date, Get-GitHubPreset, Get-PRLabelAction, Get-PRStateFromComments, Get-SearchGitHub, Open-PRInBrowser
Get-GitHubPreset#Approve-PR, Check-PRInstallerStatusInnerWrapper, Find-WinGetPackage, Get-PRLabelAction, Get-TimeclockSet, Get-WorkSearch
Get-PRLabelAction#Get-AutoValLog, Get-Date, Get-GitHubPreset, Get-PRStateFromComments, Get-UpdateHashInPR2
Get-AutoValLog#Expand-Archive, Get-BuildFromPR, Get-ChildItem, Get-GitHubPreset, Open-PRInBrowser, Remove-Item, Start-Process, Stop-Process
Get-TrackerVMValidate#Find-WinGetPackage, ForEach-Object, Get-ChildItem, Get-NextFreeVM, Get-PipelineVmGenerate,  Get-RemoveFileIfExist, Get-TrackerVMLaunchWindow, Get-TrackerVMRevert,  Get-VM, Get-YamlValue, Open-AllURL, Start-Process, Test-Admin
Get-PipelineVmGenerate#Get-Date, Get-RemoveFileIfExist, Get-TrackerVMLaunchWindow, Get-TrackerVMRevert, Get-VM, Import-VM, Remove-VMCheckpoint, Rename-VM, Start-VM, Test-Admin
Get-PipelineVmDisgenerate#Get-ConnectedVM, Get-RemoveFileIfExist, Remove-VM, Stop-Process, Stop-TrackerVM, Test-Admin, Write-Progress
Get-ImageVMStop#Get-ConnectedVM, Redo-Checkpoint, Stop-Process, Stop-TrackerVM, Test-Admin
Get-ImageVMMove#Get-Date, Get-VM, Move-VMStorage, Rename-VM, Test-Admin
Complete-TrackerVM#Get-ConnectedVM, Get-RemoveFileIfExist, Stop-Process, Stop-TrackerVM, Test-Admin
Get-TrackerVMCycle#Add-ToValidationFile, Complete-TrackerVM, Get-GitHubPreset, Get-PipelineVmDisgenerate, Get-PipelineVmGenerate, Get-TrackerVMRevert, Redo-Checkpoint


*/






//Init vars
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Imaging;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;
using System.Web.Script.Serialization;

namespace WinGetApprovalNamespace {
    public class WinGetApprovalPipeline : Form {
		//vars
        public int build = 397;//Get-RebuildPipeApp	
		public string appName = "WinGetApprovalPipeline";
		public string appTitle = "WinGet Approval Pipeline - Build ";
		public static string owner = "microsoft";
		public static string repo = "winget-pkgs";

		//public IPAddress ipconfig = (ipconfig);
		//public IPAddress remoteIP = ([ipaddress](($ipconfig[($ipconfig | Select-String "vEthernet").LineNumber..$ipconfig.Length] | Select-String "IPv4 Address") -split ": ")[1]).IPAddressToString;
		public static string RemoteMainFolder = "//$remoteIP/";
		public string SharedFolder = RemoteMainFolder+"/write";

		public static string MainFolder = "C:\\ManVal";
		public string runPath = MainFolder+"\\vm\\"; //VM working folder;
		public string vmCounter = MainFolder+"\\vmcounter.txt";
		public string VMversion = MainFolder+"\\VMversion.txt";
		public string LogFile = MainFolder+"\\misc\\ApprovedPRs.txt";
		public string PeriodicRunLog = MainFolder+"\\misc\\PeriodicRunLog.txt";
		
		public static string logsFolder = MainFolder+"\\logs"; //VM Logs folder;
		public string timecardfile = logsFolder+"\\timecard.txt";
		public string TrackerModeFile = logsFolder+"\\trackermode.txt";

		public static string writeFolder = MainFolder+"\\write"; //Folder with write permissions;
		public string SharedErrorFile = writeFolder+"\\err.txt";
		public string StatusFile = writeFolder+"\\status.csv";

		public static string ReposFolder = "C:\\repos\\"+repo;
		public string DataFileName = ReposFolder+"\\Tools\\ManualValidationPipeline.csv";

		public static string imagesFolder = MainFolder+"\\Images"; //VM Images folder;
		public string Win10Folder = imagesFolder+"\\Win10-Created010424-Original";
		public string Win11Folder = imagesFolder+"\\Win11-Created010424-Original";

		public static string GitHubBaseUrl = "https://github.com/"+owner+"/"+repo;
		public static string GitHubContentBaseUrl = "https://raw.githubusercontent.com/"+owner+"/"+repo;
		public static string GitHubApiBaseUrl = "https://api.github.com/repos/"+owner+"/"+repo;
		public string ADOMSBaseUrl = "https://dev.azure.com/ms";

		public string CheckpointName = "Validation";
		public string VMUserName = "user"; //Set to the internal username you're using in your VMs.;
		public string GitHubUserName = "stephengillie";
		//public string SystemRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb;

		public int displayLine = 0;

		public static string string_PRRegex = "[0-9]{5,6}";
		public static string string_hashPRRegex = "[//]"+string_PRRegex;
		public static string string_hashPRRegexEnd = string_hashPRRegex+"$";
		public static string string_colonPRRegex = string_PRRegex+"[:]";
		
        public Regex regex_PRRegex = new Regex(@string_PRRegex);
        public Regex regex_hashPRRegex = new Regex(@string_hashPRRegex);
        public Regex regex_hashPRRegexEnd = new Regex(@string_hashPRRegexEnd);
        public Regex regex_colonPRRegex = new Regex(@string_colonPRRegex);
		
		public string file_GitHubToken = "C:\\Users\\Stephen.Gillie\\Documents\\PowerShell\\ght.txt";
		public string GitHubToken;
		public bool TokenLoaded = false;
		public int GitHubRateLimitDelay = 333;

		public bool debuggingView = false;
		public Process[] processes = Process.GetProcesses(); //Get-Process
		JavaScriptSerializer serializer = new JavaScriptSerializer();//JSON

		//ui
		public RichTextBox outBox = new RichTextBox();
		public RichTextBox outBox_val, outBox_vm;
		public System.Drawing.Bitmap myBitmap;//Depreciate
		public System.Drawing.Graphics pageGraphics;//Depreciate?
		public Panel pagePanel;
		public ContextMenuStrip contextMenu1;//Menu?

		public TextBox inputBox_PRNumber, inputBox_Status;
        public Button btn0, btn1, btn2, btn3, btn4, btn5, btn6, btn7, btn8, btn9;
        public Button btn10, btn11, btn12, btn13, btn14, btn15, btn16, btn17, btn18, btn19;
        public Button btn20, btn21, btn22, btn23, btn24, btn25, btn26, btn27, btn28;

		//Grid
		public static int gridItemWidth = 70;
		public static int gridItemHeight = 45;

		public int lineHeight = 14;
		public int WindowWidth = gridItemWidth*10+35;
		public int WindowHeight = gridItemHeight*11+22;

		//Depreciate or bust
		public string[] history = new string[0];//Depreciate
		//public List<string> history = new List<string>();
		public int historyIndex = 0;//Depreciate
		public string[] parsedHtml = new string[1];






		//Boilerplate
        [STAThread]
        static void Main() {
            Application.EnableVisualStyles();
			Application.SetCompatibleTextRenderingDefault(false);
			Application.Run(new WinGetApprovalPipeline());
        }// end Main
		
        public WinGetApprovalPipeline() {
			if (TokenLoaded == false) {
				GitHubToken = GetContent(file_GitHubToken);
				if (GitHubToken.Length > 0) {
					TokenLoaded = true;
				}
			}

			System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
			timer.Interval = (1 * 1000); // 10 secs
			timer.Tick += new EventHandler(timer_Run);
			timer.Start();
			
			this.Text = appTitle + build;
			this.Size = new Size(WindowWidth,WindowHeight);
			this.StartPosition = FormStartPosition.CenterScreen;
			this.Resize += new System.EventHandler(this.OnResize);
			this.AutoScroll = true;
			this.Icon = Icon.ExtractAssociatedIcon(System.Reflection.Assembly.GetExecutingAssembly().Location);
			Array.Resize(ref history, history.Length + 2);
			history[historyIndex] = "about:blank";
			historyIndex++;


			drawMenuBar();
			drawUrlBoxAndGoButton();
			//drawOutBox();
			RefreshStatus();

   
        } // end WinGetApprovalPipeline		






		//UI top-of-box
		public void drawButton(ref Button button, int pointX, int pointY, int sizeX, int sizeY,string buttonText, EventHandler buttonOnclick){
			button = new Button();
			button.Text = buttonText;
			button.Location = new Point(pointX, pointY);
			button.Size = new Size(sizeX, sizeY);
			button.Click += new EventHandler(buttonOnclick);
			Controls.Add(button);
		}// end drawButton

		public void drawOutBox(ref RichTextBox outBox, int pointX,int pointY,int sizeX,int sizeY,string text, string name){
			outBox = new RichTextBox();
			outBox.Text = text;
			outBox.Name = name;
			outBox.Multiline = true;
			outBox.AcceptsTab = true;
			outBox.WordWrap = true;
			outBox.ReadOnly = true;
			outBox.DetectUrls = true;
			outBox.Font = new Font("Calibri", 14);
			outBox.Location = new Point(pointX, pointY);
			//outBox.LinkClicked  += new LinkClickedEventHandler(Link_Click);
			outBox.Width = sizeX;
			outBox.Height = sizeY;
			//outBox.Dock = DockStyle.Fill;
			outBox.ScrollBars = System.Windows.Forms.RichTextBoxScrollBars.None;


			//outBox.BackColor = Color.Red;
			//outBox.ForeColor = Color.Blue;
			//outBox.RichTextBoxScrollBars = ScrollBars.Both;
			//outBox.AcceptsReturn = true;

			Controls.Add(outBox);
		}// end drawOutBox
		
		public void drawUrlBox(ref TextBox urlBox, int pointX, int pointY, int sizeX, int sizeY,string text){
			urlBox = new TextBox();
			urlBox.Text = text;
			urlBox.Name = "urlBox";
			urlBox.Font = new Font("Calibri", 14);
			urlBox.Location = new Point(pointX, pointY);
			urlBox.Width = sizeX;
			urlBox.Height = sizeY;
			urlBox.KeyUp += urlBox_KeyUp;
			Controls.Add(urlBox);
		}

		public void drawUrlBoxAndGoButton(){
			int inc = 0;
			int row0 = gridItemHeight*inc;inc++;
			int row1 = gridItemHeight*inc;inc++;
			int row2 = gridItemHeight*inc;inc++;
			int row3 = gridItemHeight*inc;inc++;
			int row4 = gridItemHeight*inc;inc++;
 			int row5 = gridItemHeight*inc;inc++;
 			int row6 = gridItemHeight*inc;inc++;
 			int row7 = gridItemHeight*inc;inc++;
 			int row8 = gridItemHeight*inc;inc++;
 			int row9 = gridItemHeight*inc;inc++;
 			
			inc = 0;
 			int col0 = gridItemWidth*inc;inc++;
 			int col1 = gridItemWidth*inc;inc++;
 			int col2 = gridItemWidth*inc;inc++;
 			int col3 = gridItemWidth*inc;inc++;
 			int col4 = gridItemWidth*inc;inc++;
 			int col5 = gridItemWidth*inc;inc++;
 			int col6 = gridItemWidth*inc;inc++;
 			int col7 = gridItemWidth*inc;inc++;
 			int col8 = gridItemWidth*inc;inc++;
 			int col9 = gridItemWidth*inc;inc++;
 			 
			
			drawOutBox(ref outBox_vm, col0, row0, gridItemWidth*6,gridItemHeight*5, "", "outBox_vm");

			//Make gridItemWidth*2 when AddWaiver is disabled.
 			drawButton(ref btn3, col6, row0, gridItemWidth, gridItemHeight, "Add Waiver", Add_Waiver_Button_Click);
 			drawButton(ref btn3, col7, row0, gridItemWidth, gridItemHeight, "Open In Browser", Open_In_Browser_Button_Click);
			drawUrlBox(ref inputBox_PRNumber,col8, row0, gridItemWidth*2,gridItemHeight,"000000");
 			
			drawButton(ref btn2, col6, row1, gridItemWidth, gridItemHeight, "(Clipboard) Needs Feedback", Needs_Feedback_Button_Click);
			drawButton(ref btn27, col7, row1, gridItemWidth, gridItemHeight, "Work Search", Work_Search_Button_Click); 
 			drawButton(ref btn4, col8, row1, gridItemWidth, gridItemHeight, "(comments) Retry", Retry_Button_Click);
 			drawButton(ref btn5, col9, row1, gridItemWidth, gridItemHeight, "Approved", Approved_Button_Click);
 			
 			drawButton(ref btn6, col6, row2, gridItemWidth, gridItemHeight, "(ADOBuild) Blocking Issue", Blocking_Issue_Button_Click);
 			drawButton(ref btn7, col7, row2, gridItemWidth, gridItemHeight, "(Log RL) Check Installer", Check_Installer_Button_Click);
 			drawButton(ref btn8, col8, row2, gridItemWidth, gridItemHeight, "(ULog RL) Project File", Project_File_Button_Click);
 			drawButton(ref btn9, col9, row2, gridItemWidth, gridItemHeight, "(IsMatch) Closed", Closed_Button_Click);
 			
 			drawButton(ref btn14, col6, row3, gridItemWidth, gridItemHeight, "(Log RL) Defender Fail", Defender_Fail_Button_Click);
 			drawButton(ref btn15, col7, row3, gridItemWidth, gridItemHeight, "(CSV VMver) Automation Block", Automation_Block_Button_Click);
 			drawButton(ref btn16, col8, row3, gridItemWidth, gridItemHeight, "(Reply) Installer Not Silent", Installer_Not_Silent_Button_Click);
 			drawButton(ref btn17, col9, row3, gridItemWidth, gridItemHeight, "(StdComm) Installer Missing", Installer_Missing_Button_Click);
			
			drawButton(ref btn24, col6, row4, gridItemWidth, gridItemHeight, "(Log RL) Needs PackageUrl", Needs_PackageUrl_Button_Click);
			drawButton(ref btn25, col7, row4, gridItemWidth, gridItemHeight, "(Log RL) Manifest One Per PR", Manifest_One_Per_PR_Button_Click);
			drawButton(ref btn26, col8, row4, gridItemWidth, gridItemHeight, "(Log RL) Merge Conflicts", Merge_Conflicts_Button_Click);
 			drawButton(ref btn13, col9, row4, gridItemWidth, gridItemHeight, "(VMVer) Network Blocker", Network_Blocker_Button_Click);
			
			drawOutBox(ref outBox_val, col0, row5, this.ClientRectangle.Width,gridItemHeight*4, "", "outBox_val");
			
 			drawButton(ref btn10, col0, row9, gridItemWidth, gridItemHeight, "Bulk Approving", Approving_Button_Click);
			drawButton(ref btn18, col1, row9, gridItemWidth, gridItemHeight, "Individual Validations", Validating_Button_Click);
 			drawButton(ref btn11, col2, row9, gridItemWidth, gridItemHeight, "IEDS", IEDS_Button_Click);
			drawButton(ref btn19, col3, row9, gridItemWidth, gridItemHeight, "Idle", Idle_Button_Click);
			drawButton(ref btn19, col4, row9, gridItemWidth, gridItemHeight, "Config", Config_Button_Click);
			
			drawUrlBox(ref inputBox_Status,col8, row9, gridItemWidth*2,gridItemHeight,"000000");

 	   }// end drawGoButton

		public void OnResize(object sender, System.EventArgs e) {
			//outBox.Height = ClientRectangle.Height - gridItemHeight;
			//outBox.Width = ClientRectangle.Width - 0;
			//inputBox_PRNumber.Width = ClientRectangle.Width - gridItemWidth*2;
			//btn1.Left = ClientRectangle.Width/4;
		}

/*Minimize
		public void picMinimize_Click(object sender, EventArgs e) {
           try
           {
               panelUC.Visible = false;                     ; //change visible status of your form, etc.
               this.WindowState = FormWindowState.Minimized; //minimize
               minimizedFlag = true;                        ; //set a global flag
           }
           catch (Exception) {

           }

		}

		public void mainForm_Resize(object sender, EventArgs e) {
           ; //check if form is minimized, and you know that this method is only called if and only if the form get a change in size, meaning somebody clicked in the taskbar on your application
			if (minimizedFlag == true) {
				panelUC.Visible = true;     ; //make your panel visible again! thats it
				minimizedFlag = false;      ; //set flag back
			}
		}
	}
*/
		

		private void timer_Run(object sender, EventArgs e) {
			RefreshStatus();

			string clip = Clipboard.GetText();
			Regex regex = new Regex("^[0-9]{6}$");
			string[] clipSplit = clip.Replace("\r\n","\n").Replace("\n"," ").Replace("/"," ").Replace("#"," ").Split(' ');
			string c = clipSplit.Where(n => regex.IsMatch(n)).FirstOrDefault();
			if (null != c) {
				if (regex.IsMatch(c)) {
					inputBox_PRNumber.Text = "#"+c;
				}
			}
			
			inputBox_Status.Text = GetMode();
		}

		//Menu
		public void Debugging_Click(object sender, EventArgs e) {
			if (debuggingView) {
				debuggingView = false;
				loadNewPage();
			} else {
				debuggingView = true;
				loadNewPage();
			}
		}// end Save_Click
		
		public void About_Click (object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
		} // end Link_Click
/*
Gilgamech is making web browsers, games, self-driving RC cars, and other technology sundries.
*/

		public void WordWrap_Click (object sender, EventArgs e) {
			// Link
			// historyIndex++;
			// inputBox_PRNumber.Text = e.LinkText;
			// history[historyIndex] = inputBox_PRNumber.Text;
			// loadNewPage();
		} // end Link_Click

		public void TextBox_Link (object sender, LinkLabelLinkClickedEventArgs e) {
			Array.Resize(ref history, history.Length + 1);
			historyIndex++;
			history[historyIndex] = e.Link.LinkData.ToString();
			// inputBox_PRNumber.Text = history[historyIndex];
			loadNewPage();
		} // end TextBox_Link
		
		public void Save_Click(object sender, EventArgs e) {
			// save
					MessageBox.Show("You're saved");
		}// end Save_Click

		public void Open_Click(object sender, EventArgs e) {
			// save
				displayLine = 1;
				MessageBox.Show("You're opened");
		}// end Open_Click

		public void Copy_Click(object sender, EventArgs e) {
			// save
					MessageBox.Show("You're copied");
		}// end Copy_Click

		public void Paste_Click(object sender, EventArgs e) {
			// save
				MessageBox.Show("You're pasted");
				Graphics pageGraphics = outBox.CreateGraphics();
				Bitmap myBitmap = new Bitmap(WindowWidth, WindowHeight);
				outBox.DrawToBitmap(myBitmap, new Rectangle(0, 0, myBitmap.Width, myBitmap.Height));
				DrawRect(WindowWidth/2, WindowHeight/2, gridItemHeight, gridItemWidth, ref pageGraphics);
		}// end Paste_Click






//Tabs
//RunTracker
//PRWatch
//WorkSearch






//Automation Tools
//GitHubPreset
//LabelAction

		public string AddWaiver(int PR) {
			dynamic Labels = FromJson(InvokeGitHubPRRequest(PR ,"GET","labels","","issues","content"));
			string string_out = "";
			foreach (dynamic Label in Labels) {
				string Labelname = Label["name"];
				string Waiver = "";
				if (Labelname == MagicLabels[2]){
					//GitHubPreset(PR,"Completed")l
					AddPRToRecord(PR,"Manual");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[31]){
					AddPRToRecord(PR,"Waiver");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[24]){
					AddPRToRecord(PR,"Waiver");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[25]){
					AddPRToRecord(PR,"Waiver");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[26]){
					//GitHubPreset(PR,"Approved")l
				} else if (Labelname == MagicLabels[15]){
					AddPRToRecord(PR,"Waiver");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[16]){
					AddPRToRecord(PR,"Waiver");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[27]){
					AddPRToRecord(PR,"Waiver");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[21]){
					AddPRToRecord(PR,"Waiver");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[20]){
					AddPRToRecord(PR,"Waiver");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[22]){
					AddPRToRecord(PR,"Waiver");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[23]){
					AddPRToRecord(PR,"Waiver");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[28]){
					AddPRToRecord(PR,"Waiver");
					Waiver = Labelname;
				} else if (Labelname == MagicLabels[29]){
					//GitHubPreset(PR,"Completed")l
					AddPRToRecord(PR,"Manual");
				} else if (Labelname == MagicLabels[6]){
					//GitHubPreset(PR,"Completed")l
					AddPRToRecord(PR,"Manual");
				}
				if (Waiver != "") {
					 string_out += InvokeGitHubPRRequest(PR,"POST","comments","@wingetbot waivers Add "+Waiver,"issues","StatusDescription");
				}; //end if Waiver
			}; //end Foreach Label
			return string_out;
		} //end Add-Waiver

//SearchGitHub

//[ValidateSet("AgreementMismatch","AppFail","Approve","AutomationBlock","AutoValEnd","AppsAndFeaturesNew","AppsAndFeaturesMissing","DriverInstall","DefenderFail","HashFailRegen","InstallerFail","InstallerMissing","InstallerNotSilent","NormalInstall","InstallerUrlBad","ListingDiff","ManValEnd","ManifestVersion","NoCause","NoExe","NoRecentActivity","NotGoodFit","OneManifestPerPR","Only64bit","PackageFail","PackageUrl","Paths","PendingAttendedInstaller","PolicyWrapper","RemoveAsk","SequenceNoElements","Unattended","Unavailable","UrlBad","VersionCount","WhatIsIEDS","WordFilter")]
		public string CannedMessage (string Message, string UserInput = "") {
			string string_out = "";
			string Username = "@"+UserInput.Replace(" ","")+",";
			string greeting = "Hi "+ Username + Environment.NewLine + Environment.NewLine;
			//Most of these aren't used frequently enough to store and should be depreciated.
			if (Message == "AgreementMismatch"){
				string_out = greeting  + "This package uses Agreements, but this PR's AgreementsUrl doesn't match the AgreementsUrl on file.";
			} else if (Message == "AppsAndFeaturesNew"){
				string_out = greeting + "This manifest adds Apps and Features entries that aren't present in previous PR versions. These entries should be added to the previous versions, or removed from this version.";
			} else if (Message == "AppsAndFeaturesMissing"){
				string_out = greeting + "This manifest removes Apps and Features entries that are present in previous PR versions. These entries should be added to this version, to maintain version matching, and prevent the 'upgrade always available' situation with this package.";
			} else if (Message == "AppFail"){
				string_out = greeting + "The application installed normally, but gave an error instead of launching:" + Environment.NewLine;
			} else if (Message == "Approve"){
				string_out = greeting + "Do you approve of these changes?";
			} else if (Message == "AutomationBlock"){
				string_out = "This might be due to a network block of data centers, to prevent automated downloads.";
			} else if (Message == "UserAgentBlock"){
				string_out = "This might be due to user-agent throttling.";
			} else if (Message == "AutoValEnd"){
				string_out = "Automatic Validation ended with:" + Environment.NewLine + "> " + UserInput;
			} else if (Message == "DriverInstall"){
				string_out = greeting + "The installation is unattended, but installs a driver which isn't unattended:" + Environment.NewLine + "Unfortunately, installer switches are not usually provided for this situation. Are you aware of an installer switch to have the driver silently install as well?";
			} else if (Message == "DefenderFail"){
				string_out = greeting + "The package didn't pass a Defender or similar security scan. This might be a false positive and we can rescan tomorrow.";
			} else if (Message == "HashFailRegen"){
				string_out = "Closing to regenerate with correct hash.";
			} else if (Message == "InstallerFail"){
				string_out = greeting + "The installer did not complete:" + Environment.NewLine;
			} else if (Message == "InstallerMissing"){
				string_out = greeting + "Has the installer been removed?";
			} else if (Message == "InstallerNotSilent"){
				string_out = greeting + "The installation isn't unattended. Is there an installer switch to have the package install silently?";
			} else if (Message == "ListingDiff"){
				string_out = "This PR omits these files that are present in the current manifest:" + Environment.NewLine + "> " + UserInput;
			} else if (Message == "ManifestVersion"){
				string_out = greeting + "We don't often see the `1.0.0` manifest version anymore. Would it be possible to upgrade this to the [1.5.0]($GitHubBaseUrl/tree/master/doc/manifest/schema/1.5.0) version, possibly through a tool such as [WinGetCreate](https://learn.microsoft.com/en-us/windows/package-manager/package/manifest?tabs=minschema%2Cversion-example), [YAMLCreate]($GitHubBaseUrl/blob/master/Tools/YamlCreate.ps1), or [Komac](https://github.com/russellbanks/Komac)? ";
			} else if (Message == "ManValEnd"){
				string_out = "Manual Validation ended with:" + Environment.NewLine + "> " + UserInput;
			} else if (Message == "NoCause"){
				string_out = "I'm not able to find the cause for this error. It installs and runs normally on a Windows 10 VM.";
			} else if (Message == "NoExe"){
				string_out = greeting + "The installer doesn't appear to install any executables, only supporting files:" + Environment.NewLine + Environment.NewLine + "Is this expected?";
			} else if (Message == "NoRecentActivity"){
				string_out = "No recent activity.";
			} else if (Message == "NotGoodFit"){
				string_out = greeting + "Unfortunately, this package might not be a good fit for inclusion into the WinGet public manifests. Please consider using a local manifest (\\WinGet install --manifest C:\\path\\to\\manifest\\files\\) for local installations. ";
			} else if (Message == "NormalInstall"){
				string_out = "This package installs and launches normally on a Windows 10 VM.";
			} else if (Message == "OneManifestPerPR"){
				string_out = greeting + "We have a limit of 1 manifest change, addition, or removal per PR. This PR modifies more than one PR. Can these changes be spread across multiple PRs?";
			} else if (Message == "Only64bit"){
				string_out = greeting + "Validation failed on the x86 package, and x86 packages are validated on 32-bit OSes. So this might be a 64-bit package.";
			} else if (Message == "PackageFail"){
				string_out = greeting + "The package installs normally, but fails to run:" + Environment.NewLine;
			} else if (Message == "PackageUrl"){
				string_out = greeting + "Could you add a PackageUrl?";
			} else if (Message == "Paths"){
				string_out = "Please update file name and path to match this change.";
			} else if (Message == "PendingAttendedInstaller"){
				string_out = "Pending:" + Environment.NewLine + "* https://github.com/microsoft/winget-cli/issues/910";
			} else if (Message == "PolicyWrapper"){
				string_out = "<!--" + Environment.NewLine + "[Policy] " + UserInput + Environment.NewLine + "-->";
			} else if (Message == "RemoveAsk"){
				string_out = greeting + "This package installer is still available. Why should it be removed?";
			} else if (Message == "SequenceNoElements"){
				string_out = "> Sequence contains no elements" + Environment.NewLine + Environment.NewLine + " - $GitHubBaseUrl/issues/133371";
			} else if (Message == "Unavailable"){
				string_out = greeting + "The installer isn't available from the publisher's website:";
			} else if (Message == "Unattended"){
				string_out = greeting + "The installation isn't unattended:" + Environment.NewLine + Environment.NewLine + "Is there an installer switch to bypass this and have it install automatically?";
			} else if (Message == "UrlBad"){
				string_out = greeting + "I'm not able to find this InstallerUrl from the PackageUrl. Is there another page on the developer's site that has a link to the package?";
			} else if (Message == "VersionCount"){
				string_out = greeting + "This manifest has the highest version number for this package. Is it available from another location? (This might be in error if the version is switching from semantic to string, or string to semantic.)";
			} else if (Message == "WhatIsIEDS"){
				string_out = greeting + "The label `Internal-Error-Dynamic-Scan` is a blanket error for one of a number of internal pipeline errors or issues that occurred during the Dynamic Scan step of our validation process. It only indicates a pipeline issue and does not reflect on your package. Sorry for any confusion caused.";
			} else if (Message == "WordFilter"){
				string_out = "This manifest contains a term that is blocked:" + Environment.NewLine + Environment.NewLine + "> " + UserInput;
			}
			string_out  += Environment.NewLine + Environment.NewLine + "(Automated response - build " + build + ".)";
			return string_out;
		}

//AutoValLog
//RandomIEDS






		//PR tools
		//Add user to PR: Invoke-GitHubPRRequest -Method $Method -Type "assignees" -Data $User -Output StatusDescription
		//Approve PR (needs work): Invoke-GitHubPRRequest -PR $PR -Method Post -Type reviews
		public string InvokeGitHubPRRequest (int PR, string Method = "GET",string Type = "labels",string Data = "",string Path = "issues",string Output = "StatusDescription",bool JSON = false) {
		//Method [ValidateSet("GET","DELETE","PATCH","POST","PUT")] 
		//Type [ValidateSet("assignees","comments","commits","files","labels","reviews","")]
		//Path [ValidateSet("issues","pulls")]
		//Output [ValidateSet("Content","Silent","StatusDescription")][
			Dictionary<string,object> Response = new Dictionary<string, object>();
			string Url = GitHubApiBaseUrl+"/"+Path+"/"+PR+"/"+Type;
			string commitUrl = GitHubApiBaseUrl+"/pulls/"+PR+"/commits";
			//dynamic prData = FromJson(InvokeGitHubRequest(commitUrl));
			string commit = "";//((prData["commit"]["url"].Split("/"))[-1]);

			if ((Type == "") || (Type == "files") || (Type == "reviews")){
				Path = "pulls";
				Url = GitHubApiBaseUrl+"/"+Path+"/"+PR+"/"+Type;
			} else if (Type == "comments") {
				Response.Add("body",Data);
			} else if (Type == "commits") {
				Url = GitHubApiBaseUrl+"/"+Type+"/"+commit;
			} else if (Type == "reviews") {
				Path = "pulls";
				Response.Add("body",Data);
				Response.Add("commit",commit);
				Response.Add("event","APPROVE");
			} else if (Type == "") {
				//Response.title = "";
				//Response.body = "";
				Response.Add("state","closed");
				Response.Add("base","master");
			} else {
				Response.Add("ResponseType",Data);
			}

			Url = Url.Replace("/$","");
			
			string output_var;
			if (Method == "GET") {
				output_var = InvokeGitHubRequest(Url,Method);
			} else {
				string Body = ToJson(Response);
				output_var = InvokeGitHubRequest(Url,Method,Body);
			}

			if (null == output_var) {
				return "!";
			} else {
				return output_var;
			}
		}

		public string ApprovePR(int PR,string Data = "") {
			string commitUrl = GitHubApiBaseUrl+"/pulls/"+PR+"/commits";
			//dynamic prData = FromJson(InvokeGitHubRequest(commitUrl));
			string commit = "";//((prData["commit"]["url"].Split("/"))[-1]);
			string Url = GitHubApiBaseUrl+"/pulls/"+PR+"/reviews";


			Dictionary<string,object> Response = new Dictionary<string, object>();
			Response.Add("body",Data);
			Response.Add("commit",commit);
			Response.Add("event","APPROVE");
			string Body = ToJson(Response);
			
			string out_var = InvokeGitHubRequest(Url,"Post",Body);
			return out_var;
		}

		public string AddGitHubReviewComment (int PR, string Comment,int? StartLine,int Line) {
			dynamic Commit = FromJson(InvokeGitHubPRRequest(PR, "Get", "commits","","","content"));
			string CommitID = Commit["sha"];
			string Filename = Commit["files"]["filename"];
			string Side = "RIGHT";
			if (Filename.GetType().BaseType.Name == "Array") {
				//Filename = Filename[0];
			}

			Dictionary <string,object> Response = new Dictionary <string,object>();
			Response.Add("body", Comment);
			Response.Add("body", Comment);
			Response.Add("Commit_id", CommitID);
			Response.Add("path", Filename);
			if (null != StartLine) {
				Response.Add("start_line", StartLine);
			}
			Response.Add("start_side", Side);
			Response.Add("line", Line);
			Response.Add("side", Side);
			string Body = ToJson(Response);

			string uri = GitHubApiBaseUrl+"/pulls/"+PR+"/comments";
			string string_out = InvokeGitHubRequest(uri, WebRequestMethods.Http.Post, Body);
			return string_out;//.StatusDescription;
		}

		public int ADOBuildFromPR (int PR) {
			dynamic content = FromJson(webRequest(ADOMSBaseUrl+"/"+repo+"/_apis/build/builds?branchName=refs/pull/"+PR+"/merge&api-version=6.0"));
			string href = content["value"][0]["_links"]["web"]["href"];
			int PRbuild = Int32.Parse(href.Split('=')[1]);
			return PRbuild;
		}

		public List<string> LineFromCommitFile(int PR, int LogNumber = 36, int Length = 0){
			int PRbuild = ADOBuildFromPR(PR);
			//int MatchOffset = (-1); 
			//string SearchString = "Specified hash doesn't match"; 

			string content = webRequest(ADOMSBaseUrl+"/ed6a5dfa-6e7f-413b-842c-8305dd9e89e6/_apis/build/builds/"+PRbuild+"/logs/"+LogNumber);
			string[] Log = content.Split('\n'); 
			//string MatchLine = ((Log | Select-String -SimpleMatch SearchString).LineNumber + MatchOffset | where {_ > 0});
			
			List<string> output = new List<string>();
			//foreach (Match in MatchLine) {
				//output += (Log.substring(Match..(Match+Length)));
			//}
			return output;
		}

//GetPRApproval

		public string ReplyToPR (int PR,string string_CannedMessage,string Policy = ""){
/*
			Dictionary<string,object> PRContent = new Dictionary<string,object>();
			PRContent = FromJson(InvokeGitHubPRRequest(PR,"","content"));
			string from_mid = ToJson(PRContent["user"]);
			Dictionary<string,object> to_user = new Dictionary<string,object>();
			to_user = FromJson(from_mid);
			string string_UserInput = to_user["login"].ToString();
*/
			string string_UserInput = "test";
			
			string Body = CannedMessage(string_CannedMessage,string_UserInput);
			if (Policy != "") {
				Body += "\n<!--\n[Policy] "+Policy+"\n-->";
			}
			return InvokeGitHubPRRequest(PR,"Post","comments",Body,"issues","StatusDescription");
		}

		public bool CheckStandardPRComments (int PR) {
			bool out_bool = false;
			Dictionary<string,object> comments = new Dictionary<string,object>();
			comments = FromJson(InvokeGitHubPRRequest(PR,"GET","comments","","","content"));
			foreach (string StdComment in StandardPRComments) {
				if (!comments.Keys.Any(key => key.Contains(StdComment))) {
					out_bool = true;
				}
			}
			return out_bool;
		}

/*PRStateFromComments
		public string PRStateFromComments (int PR){
			string[] Comments = InvokeGitHubPRRequest(PR, "comments","","","content"); //| select created_at,@{n="UserName";e={$_.user.login -replace "\[bot\]"}},body)
			//Robot usernames
			string Wingetbot = "wingetbot";
			string AzurePipelines = "azure-pipelines";
			string FabricBot = "microsoft-github-policy-service";
			Dictionary<string,object> string_out = new Dictionary<string,object>();
			
			foreach (Dictionary<string,object> Comment in Comments) {
				string State = "";
				string Comment_created_at = "test";//[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(Comment.created_at, 'Pacific Standard Time')
				if (string.Equals(Comment.UserName, Wingetbot) && string.Equals(Comment.body, "Service Badge")) {
					State = "PreRun";
				}
				if (string.Contains(Comment.body, "AzurePipelines run") || 
				string.Contains(Comment.body, "AzurePipelines run") || 
				string.Contains(Comment.body, "azp run") || 
				string.Contains(Comment.body, "wingetbot run")) {
					State = "PreValidation";
				}
				if (string.Equals(Comment.UserName, AzurePipelines) && string.Contains(Comment.body, "Azure Pipelines successfully started running 1 pipeline")) {
					State = "Running";
				}
				if (string.Equals(Comment.UserName, FabricBot) && string.Contains(Comment.body, "The check-in policies require a moderator to approve PRs from the community")) {
					State = "PreApproval";
				}
				if (string.Equals(Comment.UserName, GitHubUserName) && string.Contains(Comment.body, "The package didn't pass a Defender or similar security scan")) {
					State = "DefenderFail";
				}
				if (string.Equals(Comment.UserName, GitHubUserName) && string.Contains(Comment.body, "Status Code: 200")) {
					State = "InstallerAvailable";
				}
				if (string.Equals(Comment.UserName, GitHubUserName) && string.Contains(Comment.body, "Response status code does not indicate success")) {
					State = "InstallerRemoved";
				}
				if (string.Equals(Comment.UserName, GitHubUserName) && string.Contains(Comment.body, "which is greater than the current manifest's version")) {
					State = "VersionParamMismatch";
				}
				if (string.Equals(Comment.UserName, FabricBot) && (
				string.Equals(Comment.body, "The package manager bot determined there was an issue with one of the installers listed in the url field") || //URL error
				string.Equals(Comment.body, "The package manager bot determined there was an issue with installing the application correctly") || //Validation-Installation-Error
				string.Equals(Comment.body, "The pull request encountered an internal error and has been assigned to a developer to investigate") ||  //Internal-Error
				string.Equals(Comment.body, "this application failed to install without user input")  || //Validation-Unattended-Failed
				string.Equals(Comment.body, "Please verify the manifest file is compliant with the package manager") //Manifest-Validation-Error
				)) {
					State = "LabelAction";
				}
				if (string.Equals(Comment.UserName, FabricBot) && string.Contains(Comment.body, "One or more of the installer URLs doesn't appear valid")) {
					State = "DomainReview";
				}
				if (string.Equals(Comment.UserName, GitHubUserName) && string.Contains(Comment.body, "Sequence contains no elements")) {
					State = "SequenceError";
				}
				if (string.Equals(Comment.UserName, GitHubUserName) && string.Contains(Comment.body, "This manifest has the highest version number for this package")) {
					State = "HighestVersionRemoval";
				}
				if (string.Equals(Comment.UserName, GitHubUserName) && string.Contains(Comment.body, "SQL error or missing database")) {
					State = "SQLMissingError";
				}
				if (string.Equals(Comment.UserName, FabricBot) && string.Contains(Comment.body, "The package manager bot determined changes have been requested to your PR")) {
					State = "ChangesRequested";
				}
				if (string.Equals(Comment.UserName, FabricBot) && string.Contains(Comment.body, "I am sorry to report that the Sha256 Hash does not match the installer")) {
					State = "HashMismatch";
				}
				if (string.Equals(Comment.UserName, GitHubUserName) && string.Contains(Comment.body, "Automatic Validation ended with:")) {
					State = "AutoValEnd";
				}
				if (string.Equals(Comment.UserName, GitHubUserName) && string.Contains(Comment.body, "Manual Validation ended with:")) {
					State = "ManValEnd";
				}
				if (string.Equals(Comment.UserName, AzurePipelines) && string.Contains(Comment.body, "Pull request contains merge conflicts")) {
					State = "MergeConflicts";
				}
				if (string.Equals(Comment.UserName, FabricBot) && string.Contains(Comment.body, "Validation has completed")) {
					State = "ValidationCompleted";
				}
				if (string.Equals(Comment.UserName, Wingetbot) && string.Contains(Comment.body, "Publish pipeline succeeded for this Pull Request")) {
					State = "PublishSucceeded";
				}
				if (!string.Equals(State, "")) {
					string_out += Comment; //| select @{n="event";e={State}},created_at;
				}
			}
			return string_out;
		}
*/





		//Network tools
		//GET = Read; POST = Append; PUT = Write; DELETE = delete
		public string InvokeGitHubRequest(string Url,string Method = WebRequestMethods.Http.Get,string Body = "",bool JSON = false){
					string response_out = "";
					//This wrapper function is a relic of the PowerShell version, and should be obviated during a refactor. The need it meets in the PowerShell version - inject authentication headers into web requests, is met here directly inside the webRequest function below. But having it here during the port process (code portage) reduces the amount of work needed to port the other functions were written to use it.

			if (Body == "") {
				try {
					response_out = webRequest(Url, Method,"",true);//  Headers Body -ContentType "application/json";
				} catch (Exception e) {
					//MessageBox.Show("Wrong request!" + ex.Message, "Error");
					response_out = e.Message;
				}
			} else {
				try {
					response_out = webRequest(Url, Method, Body,true);//  Headers -ContentType "application/json";
				} catch (Exception e) {
					//MessageBox.Show("Wrong request!" + ex.Message, "Error");
					response_out = e.Message;
				}
			}

			if (JSON == true) {
			}

			return response_out;
		}
		//GitHub requires the value be the .body property of the variable. This makes more sense with CURL, Where-Object this is the -data parameter. However with webRequest it's the -Body parameter, so we end up with the awkward situation of having a Body parameter that needs to be prepended with a body property.

		public void PRInstallerStatusInnerWrapper (string Url){
			//This was a hack to get around Invoke-WebRequest hard blocking on failure, where this needed to be captured and transmitted to a PR comment. And so might not be needed here.
			//string Code = InvokeWebRequest (Url, "Head").StatusCode
			//return $Code
		}






//Validation Starts Here
//VMValidate
//ValidateByID
//ValidateByConfig
//ValidateByArch
//ValidateByScope
//ValidateByBothArchAndScope






//Manifests Etc - Section needs refactor badly
//SingleFileAutomation
//ManifestAutomation

/*This function doesn't seem to be complete. 
		public string ManifestOtherAutomation(bool Installer){
			string[] array_Title = Clipboard.GetText().Split(" version "); //Get PackageIdentifier?
			string[] array_Version = array_Title[1].Split("#");
			string PR = Version[1];
			string string_Title = array_Title[0]
			string string_Version = array_Version[0]
			if ($Installer) {
				$file = FileFromGitHub(Title,Version)
			}
		}
*/

//ManifestFile
//ManifestListing
//ListingDiff
		public string OSFromVersion(string version) {
			string string_out = "";
			try{
				version = YamlValue("MinimumOSVersion", version);
				if (Version.Parse(version) >= Version.Parse("10.0.22000.0")){
					string_out = "Win11";
				}else{
					string_out = "Win10";
				}
			} catch {
				string_out = "Win10";
			}
			return string_out;
		}








//VM Image Management
//ImageVMStart
//ImageVMStop
//ImageVMMove






//VM Pipeline Management
//VMGenerate
//VMDisgenerate
//LaunchWindow
//VMRevert
//VMComplete
//VMStop






//VM Status
		public void SetStatus(int VM, string Status = "", string Package = "",int PR = 0){
		//[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","Setup","SetupComplete","Starting","Updating","ValidationCompleted")]
			dynamic Records = FromCsv(GetContent(StatusFile));
			for (int r = 1; r < Records.Length -1; r++){
				var row = Records[r];
				if (Int32.Parse(row["vm"]) == VM) {
					if (Status != "") {
						row["status"] = Status;
					}
					if (Package != "") {
						row["Package"] = Package;
					}
					if (PR != 0) {
						row["PR"] = PR;
					}//end if PR
				}//end if row vm
			}//end for r
			OutFile(StatusFile, ToCsv(Records));
		}//end function



		//var row = Line.Where(n => n.Contains(OS)).FirstOrDefault();
	//[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","Setup","SetupComplete","Starting","Updating","ValidationCompleted")]
	//GetStatus = FromCsv(GetContent(StatusFile));
		//if (TestPath(StatusFile) == "File") {}
		//return Records;
	//}

		//WriteStatus = OutFile(StatusFile,string_out);
			

//ResetStatus
//RebuildStatus

		public void RefreshStatus() {
			try {
				
			if (TestPath(StatusFile) == "File") {
				dynamic Records = FromCsv(GetContent(StatusFile));
				try {
					if (Records != null) {
						outBox_vm.Text = "| vm | status | version | OS | Package | PR | RAM |";
						for (int r = 1; r < Records.Length -1; r++){
							var row = Records[r];
							outBox_vm.AppendText(Environment.NewLine + "| " + row["vm"] + " | " + row["status"] + " | " + row["version"] + " | " + row["OS"] + " | " + row["Package"] + " | " + row["PR"] + " | " + row["RAM"] + " | "); // 
						}//end for r
					}//end if Records
				} catch {
					outBox_vm.AppendText(null); // 
				}//end try catch
			}//end if TestPath
			} catch {}
		}//end function 





//VM Versioning
		public int GetVMVersion (string OS = "Win10") {
			//[ValidateSet("Win10","Win11")][string]OS = "Win10",
			int VMVersion;
			string VMData = GetContent(VMversion);
			List<string> Line = VMData.Split('\n').ToList();
			string Line2 = Line.Where(n => n.Contains(OS)).FirstOrDefault();
			Line2 = Line2.Replace("\"","");
			VMVersion = Int32.Parse(Line2.Split(',','"')[1]);
			return VMVersion;
		}

		public void SetVMVersion (int Version, string OS = "Win10") {
			string VMData = GetContent(VMversion);
			List<string> Line = VMData.Split('\n').ToList();
			string Line2 = Line.Where(n => n.Contains(OS)).FirstOrDefault();
			Line2 = Line2.Replace("\"","");
			int CurrentVersion = Int32.Parse(Line2.Split(',','"')[1]);
			VMData = VMData.Replace(OS+"\",\""+CurrentVersion,OS+"\",\""+Version);
			OutFile(VMversion,VMData);
		}

//RotateVMs






//VM Orchestration
//VMCycle
		public string GetMode() {
			string mode = GetContent(TrackerModeFile);
			return mode;
		}

		public void SetMode(string Status = "Validating") {
			//[ValidateSet("Approving","Idle","IEDS","Validating")]
			OutFile(TrackerModeFile,Status);
		}
//ConnectedVM
//NextFreeVM
//RedoCheckpoint






		//File Management
		public string SecondMatch(string clip, int depth = 1) {
			string[] clipArray = clip.Split('\n');
			List<string> sa_out = new List<string>();
			//If $current and $prev don't match, return the $prev element, which is $depth lines below the $current line. Start at $clip[$depth] and go until the end - this starts $current at $clip[$depth], and $prev gets moved backwards to $clip[0] and moves through until $current is at the end of the array, $clip[$clip.Length], and $prev is $depth previous, at $clip[$clip.Length - $depth].
			for (int depthUnit = depth;depthUnit < clip.Length; depthUnit++){
				string current = clipArray[depthUnit].Split(':')[0];
				string prevUnit = clipArray[depthUnit - depth];
				string prev = prevUnit.Split(':')[0];
				if (current != prev) {
					sa_out.Add(prevUnit);
				}
			}
			//Then complete the last depth items of the array by starting at clip[-depth] and work backwards through the last items in reverse order to clip[-1].
			for (int depthUnit = depth ;depthUnit > 0; depthUnit--){
				sa_out.Add(clipArray[-depthUnit]);
				
			}
		string string_joined = string.Join("\n", sa_out);
		return string_joined;
		}
/* This function isn't actively used.
public void RotateLog {
	string logYesterDate = (Get-Date -f dd) - 1
	Move-Item "$writeFolder\\logs\\$logYesterDate" "$logsFolder\\$logYesterDate"
}
*/
//RemoveFileIfExist

		/*LoadFileIfExists(FileName) = GetContent(FIleName);
			string string_out = "";
			if (TestPath(FileName) == "File") {
				string_out = GetContent(file_GitHubToken);
			} else {
				string AboutText = "GitHub token not found." + Environment.NewLine;
				string_out = AboutText;
				AboutText += file_GitHubToken + Environment.NewLine;
				MessageBox.Show(AboutText);
			}
		return string_out;
		}
*/

		public string FileFromGitHub(string PackageIdentifier, int Version, string FileName = "installer.yaml") {
			string Path = PackageIdentifier.Replace('.','/');
			string FirstLetter = PackageIdentifier[0].ToString().ToLower();
			string content = "";
			try{
				content = InvokeGitHubRequest(GitHubContentBaseUrl+"/master/manifests/"+FirstLetter+"/"+Path+"/"+Version+"/"+PackageIdentifier+"."+FileName);
			}catch{
				content = "Error";
			}
			return content;
		}

		public bool ManifestEntryCheck(string PackageIdentifier, int Version, string Entry = "AppsAndFeaturesEntries"){
			string content = FileFromGitHub(PackageIdentifier,Version);
			string string_out = "";
			string_out = string_out.Split('\n').Where(n => n.Contains(Entry)).FirstOrDefault(); // s.IndexOf(": ");
			if (string_out == "") {
				return false;
			} else {
				return true;
			}
		}

		public string DecodeGitHubFile (string Base64String) {
			var Bits = System.Convert.FromBase64String(Base64String);
			string String = System.Text.Encoding.UTF8.GetString(Bits);
			return String;
		}

		public string CommitFile(int PR, string File, string url){
			dynamic Commit = FromJson(InvokeGitHubPRRequest(PR,"commits","content"));
			if (Commit["files"]["contents_url"].GetType() == "String") {
				url =  Commit["files"]["contents_url"];
			} else {
				url =  Commit["files"]["contents_url"]["File"];
			}
			dynamic EncodedFile = FromJson(InvokeGitHubRequest(url));
			return DecodeGitHubFile(EncodedFile["content"]);
		}



//Inject into files on disk
//AddToValidationFile
//AddInstallerSwitch






//Inject into PRs
//UpdateHashInPR
//UpdateHashInPR2
//UpdateArchInPR
//DependencyToPR






//Reporting
		public void AddPRToRecord(int PR, string Action, string Title = ""){
		//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			Title = Title.Split('#')[0];
			string string_out = (PR+","+Action+","+Title + Environment.NewLine);
			OutFile(LogFile, string_out, true);
		}

		public void PRPopulateRecord(){
			dynamic Logs = FromCsv(GetContent(LogFile));
			for (int l = 1; l < Logs.Length -1; l++){
				var Log = Logs[l];
				//If the title is null, search for another with the same PR whose title isn't null. 
				if (Log["title"]  == null) {
					for (int m = 1; m < Logs.Length -1; m++){
						var ListItem = Logs[m];
						if (ListItem["title"]  != null && ListItem["PR"] == Log["PR"]) {
							Log["title"] = ListItem["title"];
						}//end if ListItem
					}//end for m
				}//end if ListItem
			}//end for l
			OutFile(LogFile, ToCsv(Logs));
		}//end function
//GetPRFromRecord
//PRReportFromRecord
//PRFullReport






//Clipboard
		public List<int> PRNumber(string string_in, bool Hash = false){
			Regex regex = regex_hashPRRegexEnd;
			List<int> list_out = new List<int>();
			if (Hash == true) {
				string_in = string_in.Replace("#","");
				regex = regex_hashPRRegexEnd;
			}
			foreach (string string_si in string_in.Split(' ')) {
				int int_si = Int32.Parse(string_si);
				if (regex.IsMatch(string_si)) {
					list_out.Add(int_si);
				}
			}
			list_out = list_out.Distinct().ToList();
			return list_out;
		}

		//SO: You can use the Distinct method to return an IEnumerable<T> of distinct items:
		//var uniqueItems = yourList.Distinct();
		//And if you need the sequence of unique items returned as a List<T>, you can add a call to ToList:
		//var uniqueItemsList = yourList.Distinct().ToList();

		public string SortedClipboard(string string_in){
			IEnumerable<string> string_array = string_in.Split('\n').Distinct();
			string string_joined = string.Join("\n", string_array);
			return string_joined;
		}

//OpenAllURLs
//OpenPRInBrowser
//YamlValue - Ready
		public string YamlValue(string ContainsString, string YamlString){
			//Split YamlString by \n
			//String where equals StringName
			YamlString = YamlString.Split(' ').Where(n => n.Contains(ContainsString)).FirstOrDefault(); // s.IndexOf(": ");
			YamlString = YamlString.Split(':')[1];
			YamlString = YamlString.Split('#')[0];
			//YamlString = (YamlString.ToCharArray() | where {$_ -match "\\S"}).Join("");
			return YamlString;
		}






//Etc
//TestAdmin - Ready
		public void TrackerProgress(int PR, string Activity, string Incrementor, string Length){
			//int Percent = System.Math.Round(Incrementor / Length*100,2);
			//Write-Progress -Activity $Activity -Status "$PR - $Incrementor / $Length = $Percent %" -PercentComplete Percent
		}

		public double ArraySum(int[] int_in){
			int sum = int_in.Sum();
			return sum;//Math.Round(sum,2);
		}

		public void GitHubRateLimit(){
			//Time, as a number, constantly increases. 
			string Url = "https://api.github.com/rate_limit";
			dynamic Unlogged_Rate = FromJson(webRequest(Url));
			//Unlogged_Rate["rate"] | select @{n="source";e={"Unlogged"}}, limit, used, remaining, @{n="reset";e={([System.DateTimeOffset]::FromUnixTimeSeconds(_.reset)).DateTime.AddHours(-8)}}
			
			dynamic Logged_Rate = FromJson(InvokeGitHubRequest(Url));
			//Response["rate"] | select @{n="source";e={"Logged"}}, limit, used, remaining, @{n="reset";e={([System.DateTimeOffset]::FromUnixTimeSeconds(_.reset)).DateTime.AddHours(-8)}}
		}

		//var data = data.Where(p => listOfProducts.Any(l => p.Name == l.Name)).ToList();
		//var matchingKeys = dict.Where(kvp => kvp.Value == 2).Select(kvp => kvp.Key);
		public dynamic GetValidationData(string Property, string Match,bool Exact){
			if (Exact == true) {
				return FromCsv(GetContent(DataFileName)).Where(n => n[Property] != null).Where(n => (string)n[Property] == Match);
			} else {
				return FromCsv(GetContent(DataFileName)).Where(n => n[Property] != null).Where(n => Match.Contains((string)n[Property]));
			}
		}


/*
public string AddValidationData(string PackageIdentifier,string GitHubUserName,string authStrictness,string authUpdateType,string autoWaiverLabel,string versionParamOverrideUserName,int versionParamOverridePR,string code200OverrideUserName,int code200OverridePR,int AgreementOverridePR,string AgreementURL,string reviewText){
//[ValidateSet("should","must")]
//[ValidateSet("auto","manual")]
	string data = (Get-Content $DataFileName | ConvertFrom-Csv)
	
	string string_out = (data | where {_.PackageIdentifier == PackageIdentifier} | Select-Object "PackageIdentifier","GitHubUserName","authStrictness","authUpdateType","autoWaiverLabel","versionParamOverrideUserName","versionParamOverridePR","code200OverrideUserName","code200OverridePR","AgreementOverridePR","AgreementURL","reviewText")
	if (null == string_out) {
		string_out = ( "" | Select-Object "PackageIdentifier","GitHubUserName","authStrictness","authUpdateType","autoWaiverLabel","versionParamOverrideUserName","versionParamOverridePR","code200OverrideUserName","code200OverridePR","AgreementOverridePR","AgreementURL","reviewText")
		string_out.PackageIdentifier = PackageIdentifier
	}

		string_out.GitHubUserName = GitHubUserName
		string_out.authStrictness = authStrictness
		string_out.authUpdateType = authUpdateType
		string_out.autoWaiverLabel = autoWaiverLabel
		string_out.versionParamOverrideUserName = versionParamOverrideUserName
		string_out.versionParamOverridePR = versionParamOverridePR
		string_out.code200OverrideUserName = code200OverrideUserName
		string_out.code200OverridePR = code200OverridePR
		string_out.AgreementURL = AgreementURL
		string_out.AgreementOverridePR = AgreementOverridePR
		string_out.reviewText = reviewText
		data += string_out
		data | sort PackageIdentifier | ConvertTo-Csv| OutFile DataFileName 
}
*/








//PR Watcher Utility functions
//GetSandbox

		public string PadRight(string PackageIdentifier,int PadChars = 45){
			string string_out = "";
			if (PackageIdentifier.Length < PadChars) {
				int int_extraSpaces = (PadChars - PackageIdentifier.Length -1);
				string string_extraSpaces = new string(' ', int_extraSpaces);
				string_out = String.Concat(PackageIdentifier, string_extraSpaces);
			//} else if (PackageIdentifier.Length > PadChars) {
				//string_out = PackageIdentifier.substring(0..(PadChars -1))
			//}
			}
			return string_out;
		}






		//Powershell functional equivalency imperatives
		//Start-Sleep = Thread.Sleep(GitHubRateLimitDelay);
		//Get-Process = Process[] processes //Above;
		//Get-Clipboard = Clipboard.GetText()
		
		///JSON
		public dynamic FromJson(string string_input) {
			dynamic dynamic_output = new System.Dynamic.ExpandoObject();
			dynamic_output = serializer.Deserialize<dynamic>(string_input);
			return dynamic_output;
		}
		
		public string ToJson(dynamic dynamic_input) {
			string string_out;
			string_out = serializer.Serialize(dynamic_input);
			return string_out;
		}
		//CSV
		public Dictionary<string, dynamic>[] FromCsv(string csv_in) {
			//CSV isn't just a 2d object array - it's an array of Dictionary<string,object>, whose string keys are the column headers. 
			string[] Rows = csv_in.Replace("\r\n","\n").Replace("\"","").Split('\n');
			string[] columnHeaders = Rows[0].Split(',');
			Dictionary<string, dynamic>[] matrix = new Dictionary<string, dynamic> [Rows.Length];
			try {
				for (int row = 1; row < Rows.Length; row++){
					matrix[row] = new Dictionary<string, dynamic>();
					//Need to enumerate values to create first row.
					string[] rowData = Rows[row].Split(',');
					try {
						for (int col = 0; col < rowData.Length; col++){
							//Need to record or access first row to match with values. 
							matrix[row].Add(columnHeaders[col].ToString(), rowData[col]);
						}
					} catch {
					}
				}
			} catch {
			}
			return matrix;
		}

		public string ToCsv(Dictionary<string, dynamic>[] matrix) {
			string csv_out = "";
			//Arrays seem to have a buffer row above and below the data.
			int topRow = 1;
			Dictionary<string, dynamic> headerRow = matrix[topRow];
			//Write header row (th). Support for multi-line headers maybe someday but not today. 
			if (headerRow != null) {
				string[] columnHeaders = new string[headerRow.Keys.Count];
				headerRow.Keys.CopyTo(columnHeaders, 0);
				//var a = matrix[0].Keys;
				foreach (string columnHeader in columnHeaders){
						csv_out += columnHeader.ToString()+",";
				}
				csv_out = csv_out.TrimEnd(',');
				// Write data rows (td).
				for (int row = topRow; row < matrix.Length -1; row++){
					csv_out += "\n";
					foreach (string columnHeader in columnHeaders){
						csv_out += matrix[row][columnHeader]+",";
					}
					csv_out = csv_out.TrimEnd(',');
				}
			}
			csv_out += "\n";
			return csv_out;
		}
		//File
		public string GetContent(string Filename) {
			string string_out = "";
			try {
				// Open the text file using a stream reader.
				using (var sr = new StreamReader(Filename)) {
					// Read the stream as a string, and write the string to the console.
					string_out = sr.ReadToEnd();
				}
			} catch (IOException e) {
				string Text = "GetContent - File could not be read:" + Environment.NewLine;
				Text += Filename + Environment.NewLine;
				Text +=  e.Message + Environment.NewLine;
				MessageBox.Show(Text, "Error");
			}
			return string_out;
		}

		public void OutFile(string path, object content, bool Append = false) {
			//From SO: Use "typeof" when you want to get the type at compilation time. Use "GetType" when you want to get the type at execution time. "is" returns true if an instance is in the inheritance tree.
			if (content.GetType() == typeof(string)) {
				string out_content = (string)content;
			//From SO: File.WriteAllLines takes a sequence of strings - you've only got a single string. If you only want your file to contain that single string, just use File.WriteAllText.
				if (Append == true) {
					File.AppendAllText(path, out_content);//string
				} else {
					File.WriteAllText(path, out_content);//string
				}
			} else {
				IEnumerable<string> out_content = (IEnumerable<string>)content;
				if (Append == true) {
					File.AppendAllLines(path, out_content);//IEnumerable<string>'
				} else {
					File.WriteAllLines(path, out_content);//string[]
				}				
			}
		}

		public string TestPath(string path) {
				string string_out = "";
				if (path != null) {
						path = path.Trim();
					if (Directory.Exists(path)) {
						string_out = "Directory";
					} else if (new[] {"\\", "/"}.Any(x => path.EndsWith(x))){// if has trailing slash then it's a directory
						string_out = "Directory";
					} else if (File.Exists(path)) {
						string_out = "File";
					} else if (string.IsNullOrWhiteSpace(Path.GetExtension(path))) {// if has extension then its a file; directory otherwise
						string_out = "File";
					} else {// neither file nor directory exists. guess intention
						string_out = "None";
					}
				} else {// neither file nor directory exists. guess intention
					string_out = "Empty";
				}
				return string_out;
			}
		//Web
		public string webRequest(string Url, string Method = WebRequestMethods.Http.Get, string Body = "",bool Authorization = false){ 
			string response_out = "";

				// SSL stuff
				//ServicePointManager.Expect100Continue = true;
				ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;

				HttpWebRequest request = (HttpWebRequest)WebRequest.Create(Url);
				
				if (Authorization == true) {
					request.Headers.Add("Authorization", "Bearer "+GitHubToken);
					request.Headers.Add("X-GitHub-Api-build", "2022-11-28");
					request.PreAuthenticate = true;
				}

				request.Method = Method;
				request.ContentType = "application/json;charset=utf-8";
				request.Accept = "application/vnd.github+json";
				request.UserAgent = "WinGetApprovalPipeline";

			try {
				if ((Body == "") || (Method ==WebRequestMethods.Http.Get)) {
				} else {
					var data = Encoding.Default.GetBytes(Body); // note: choose appropriate encoding
					request.ContentLength = data.Length;
					var newStream = request.GetRequestStream(); // get a ref to the request body so it can be modified
					newStream.Write(data, 0, data.Length);
					newStream.Close();
				} 

				} catch (Exception e) {
					//MessageBox.Show("Wrong request!" + ex.Message, "Error");
					response_out = "Request Error: " + e.Message;
				}
				
				try {
					WebResponse response = request.GetResponse();
					StreamReader sr = new StreamReader(response.GetResponseStream());
					string response_text = sr.ReadToEnd();
					response_out = response_text;
					sr.Close();
				} catch (Exception e) {
					//MessageBox.Show("Wrong request!" + ex.Message, "Error");
					response_out = "Response Error: " + e.Message;
				}
		return response_out;
		}// end webRequest	






		//VM Window Management
		public class Window {
			[DllImport("user32.dll")]
			[return: MarshalAs(UnmanagedType.Bool)]
			public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

			[DllImport("user32.dll")]
			public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

		}

		public struct RECT {
			public int Left; // x position of upper-left corner
			public int Top; // y position of upper-left corner
			public int Right; // x position of lower-right corner
			public int Bottom; // y position of lower-right corner
		}

		public RECT rect;

		public void  TrackerVMWindowLoc (int VM,ref RECT rect,string VMProcesses,IntPtr MWHandle) {
			//Need to readd the logic that finds the mainwindowhandle from the VM number.
			Window.GetWindowRect(MWHandle,out rect);
		}

		public void  TrackerVMWindowSet (int VM,int Left,int Top,int Right,int Bottom,string VMProcesses,IntPtr MWHandle) {
			Window.MoveWindow(MWHandle,Left,Top,Right,Bottom,true);
		}

		public void  TrackerVMWindowArrange() {
/*
			VMs = (Status |where {_.status -ne "Ready"}).vm
			If (VMs) {
				TrackerVMWindowSet VMs[0] 900 0 1029 860
				Base = TrackerVMWindowLoc VMs[0]
				
				For (n = 1;n < VMs.count;n++) {
					VM = VMs[n]
					
					Left = (Base.left - (100 * n))
					Top = (Base.top + (66 * n))
					TrackerVMWindowSet VM Left Top 1029 860
				}
			}
*/
		}






		//Depreciate or bust
        public void loadNewPage() {

//Download HTML file
//Parse HTML to Document variable
//Write Document variable to page
//Interpret Javascript to modify Document variable
			//history.Add(inputBox_PRNumber.Text);
			history[historyIndex] = inputBox_PRNumber.Text;
			string imageUrl = "";
			string pageSource = "";
			displayLine = 0;
			// Download website, stick source in pageSource
			//webRequest(ref pageSource, imageUrl, WebRequestMethods.Http.Get);

			// Do some replacing
			doSomeReplacing(ref pageSource);
			
			// Set form name to page title
			try {
			}catch{
			}// end try 

			
			//favicon 
			try {
				// <link rel="shortcut icon" href="/favicon.ico" type="image/vnd.microsoft.icon">
				//imageUrl = pageSource.Substring(pageSource.IndexOf("<link")+5, pageSource.IndexOf(">") - pageSource.IndexOf("<link"));
				imageUrl = findIndexOf(pageSource,"<link",">",5,0);
				//imageUrl = imageUrl.Substring(imageUrl.IndexOf("href=")+6, imageUrl.IndexOf('"') - imageUrl.IndexOf("href="));
				imageUrl = findIndexOf(imageUrl,"href=","",6,0);
				
			}catch{
				imageUrl = history[historyIndex] + "/favicon.ico";
			}// end try 
			try {
/*
using(Stream stream = Application.GetResourceStream(new Uri(imageUrl)).Stream)
{
    Icon myIcon = new System.Drawing.Icon(stream);
}
				WebClient client = new WebClient();
				Stream stream = client.OpenRead(imageUrl);
				stream.Flush();
				stream.Close();
				//this.Text += "Favicon: "+imageUrl;
*/

				WebRequest request = WebRequest.Create(imageUrl);
				request.Method = WebRequestMethods.Http.Get;// WebRequestMethods.Http.Get;
				//request.UserAgent = "WinGetApprovalPipeline";
				WebResponse response = request.GetResponse();
				Stream stream = response.GetResponseStream();
				this.Icon = new Icon(stream);
				//pictureBox1.Image = Bitmap.FromStream(stream);

			}catch{
				//this.Icon = Icon.ExtractAssociatedIcon(System.Reflection.Assembly.GetExecutingAssembly().Location);
				//this.Text = "Favicon missing:"+imageUrl+" - " + this.Text;
			}// end try 

			// Split head & body 
			//Goto <body then goto the next >
			try {
				//parsedHtml = pageSource.Substring(pageSource.IndexOf("<body"), pageSource.IndexOf("</body") - pageSource.IndexOf("<body")).Split('<');
				parsedHtml = findIndexOf(pageSource,"<body","</body",0,0).Split('<');
			}catch{
				parsedHtml = pageSource.Split('<');
			}; // end try 
			drawPage(parsedHtml);
        }// end loadNewPage

		public string findIndexOf(string pageString,string startString,string endString,int startPlus,int endPlus){
			return pageString.Substring(pageString.IndexOf(startString)+startPlus, pageString.IndexOf(endString) - pageString.IndexOf(startString)+endPlus);
        }// end findIndexOf

		public void drawPage(string[] parsedHtml){
			//pagePanel.Paint += new PaintEventHandler(drawPanel);
			string tag = "div";
			//string buttonText = "";
			
			int werdStart = 0;
			int werdSpace = 0;
			int werdEnd = 0;
			
			
			//Should delete outBox and make a new one? This is easier.
			outBox.Height = ClientRectangle.Height - gridItemHeight;
			outBox.Controls.Clear();
			outBox.Text = "";
			
			foreach (string werd in parsedHtml){
				outBox.Height += lineHeight; // 40? And add multples for word wrap?
				string append = "";
				werdSpace = 0;
				
				if (werd.IndexOf(">") >=0 ) {
					werdStart = werd.IndexOf(">")+1;
				} else {
					werdStart = 0;
				}
				
				if (werd.IndexOf("<") >=0 ) {
					werdEnd = werd.IndexOf("<");
				} else {
					werdEnd = werd.Length;
				}
				
				
				if (werd.IndexOf(" ") >=0) {
					werdSpace = werd.IndexOf(" ");
					if (werdSpace >= werdStart) {//wordStart.index > wordSpace.index (larger is after)
						try {
							tag = werd.Substring(0,werdStart);
						} catch {
							tag = "werdIndex:" +werd.IndexOf(">")+ "-werdSpace:"+werdSpace;
						}// end try
					}
					if (werdSpace <= werdStart) {//wordStart.index < wordSpace.index (smaller is before)
						try {
							tag = werd.Substring(0,werdSpace);
						} catch {
							tag = "werdIndex:" +werd.IndexOf(">")+ "-werdSpace:"+werdSpace;
						}// end try
					}
				} else {//wordSpace.index = -1
					try {
						tag = werd.Substring(0,werdStart-1);
					} catch {
						tag = "werdIndex:" +werd.IndexOf(">")+ "-werdSpace:"+werdSpace;
					}// end try
				}// end if werd

				outBox.SelectionColor = Color.Black;
				append = werd.Substring(werdStart, werdEnd - werdStart);

/*
				try {
					if (werdSpace == 0) {
					} else {
					}// end if werdStart

				} catch {
					tag = "werdIndex:" +werd.IndexOf(">")+ "-werdSpace:"+werdSpace;
				}// end try
*/

			tagSwitch(ref append, werd, tag);
				
				if (append != "") {
					outBox.AppendText(append);
				}
				
			}// end foreach string
			//this.Invalidate();
        }// end drawPage

		public void doSomeReplacing(ref string pageSource){
			// Do some replacing
			pageSource = pageSource.Replace("&lt;","<");
			pageSource = pageSource.Replace("&gt;",">");
			}

		public void tagSwitch (ref string append, string werd, string tag) {
			int itemX = 0;
			int itemY = 0;
			int itemWidth = 0;
			int itemHeight = 0;
				switch (tag) {
					case "!--":
						append = "";
						break;
					case "!DOCTYPE":
						append = "";
						break;
					case "a":
						//Parse out the link
						string linkText = "";
						if (werd.IndexOf("href=\"") >=0 ) {
				//linkText = werd.Substring(werd.IndexOf("href"), werd.IndexOf("</body") - werd.IndexOf("<body"));
				//linkText = findIndexOf(werd,"<body","</body",0,0);
							linkText = werd.Substring(werd.IndexOf("href")+6,werd.Length-werd.IndexOf("href")-6);
							linkText = linkText.Substring(0,linkText.IndexOf('"'));
						} else if (werd.IndexOf("href='") >=0 ) {
							linkText = werd.Substring(werd.IndexOf("href")+6,werd.Length-werd.IndexOf("href")-6);
							linkText = linkText.Substring(0,linkText.IndexOf("'"));
						} 
						//Add the hostname if it's implied.
						if (linkText.Substring(0,1) == "/") {
							linkText = history[historyIndex] + linkText.Substring(1,linkText.Length-1);
						};
						//outBox.SelectionColor = Color.Blue;
						//append = append + "<link = \"" + linkText + "\">";

						//Add the link to the richtextbox.
						LinkLabel link = new LinkLabel();
						link.Text = append;
						link.LinkClicked += new LinkLabelLinkClickedEventHandler(this.TextBox_Link);
						LinkLabel.Link data = new LinkLabel.Link();
						data.LinkData = @linkText;
						link.Links.Add(data);
						link.AutoSize = true;
						link.Location = this.outBox.GetPositionFromCharIndex(this.outBox.TextLength);
						this.outBox.Controls.Add(link);
						this.outBox.SelectionStart = this.outBox.TextLength;
						
						append = "";
						itemX = this.outBox.GetPositionFromCharIndex(this.outBox.TextLength).X;
						itemY = this.outBox.GetPositionFromCharIndex(this.outBox.TextLength).Y;
						itemWidth = gridItemWidth;
						itemHeight = gridItemHeight;
						drawPanel(itemX, itemY, itemWidth, itemHeight);
						
						
						
						if (debuggingView) {
						outBox.SelectionColor = Color.Black;
						if (tag.IndexOf("/") <0) {
							append = "Default - Tag: "+tag+" - werd: "+werd;
						}
						}
						break;
			}; // end switch
		} // end tagSwitch
		
		public void urlBox_KeyUp(object sender, KeyEventArgs e) {
    switch (e.KeyCode) {
        case Keys.F5:
			loadNewPage();
			e.Handled = true;
            break;
        case Keys.Enter:
			loadNewPage();
			e.Handled = true;
            break;
    }
}

		protected override void OnPaint( PaintEventArgs e ) {

			Graphics pageGraphics = outBox.CreateGraphics();
			Bitmap myBitmap = new Bitmap(WindowWidth, WindowHeight);
			outBox.DrawToBitmap(myBitmap, new Rectangle(0, 0, myBitmap.Width, myBitmap.Height));


			//pageGraphics.DrawLine(Pens.Black, new Point(0, (outBox.Lines.Length + 1) * 10), new Point(500, (outBox.Lines.Length + 1) * 10));
			if (displayLine == 1) {
				//pageGraphics.Clear(outBox.BackColor);
				DrawRect(WindowWidth/2, WindowHeight/2, gridItemHeight, gridItemWidth, ref pageGraphics);
			}

			pageGraphics.Dispose();
		}
		
		//Draw Stuff
		public void DrawString(string drawString, int x, int y, ref Graphics graphicsObj){
			System.Drawing.Font drawFont = new System.Drawing.Font("Arial", 16);
			System.Drawing.SolidBrush drawBrush = new System.Drawing.SolidBrush(System.Drawing.Color.Black);
			System.Drawing.StringFormat drawFormat = new System.Drawing.StringFormat();
			graphicsObj.DrawString(drawString, drawFont, drawBrush, x, y, drawFormat);
			drawFont.Dispose();
			drawBrush.Dispose();
		}// end DrawString

		public void DrawRect(int startX, int startY, int sizeX, int sizeY, ref Graphics graphicsObj){
			System.Drawing.SolidBrush myBrush = new System.Drawing.SolidBrush(System.Drawing.Color.Red);
			graphicsObj.FillRectangle(myBrush, new Rectangle(startX, startY, sizeX, sizeY));
			myBrush.Dispose();
		}
		
		public void drawPanel(int startX, int startY, int sizeX, int sizeY){
			Panel panel1 = new Panel();
			TextBox textBox1 = new TextBox();
			Label label1 = new Label();

			// Initialize the Panel control.
			panel1.Location = new Point(startX,startY);
			panel1.Size = new Size(sizeX, sizeY);
			// Set the Borderstyle for the Panel to three-dimensional.
			//panel1.BorderStyle = System.Windows.Forms.BorderStyle.Fixed3D;
			//panel1.TabIndex = 0;
			panel1.AutoScroll = true;
			// Initialize the Label and TextBox controls.
			label1.Location = new Point(12,16);
			label1.Text = "label1";
			label1.Size = new Size(104, 16);
			textBox1.Location = new Point(16,320);
			textBox1.Text = "";
			textBox1.Size = new Size(152, 20);

			// Add the Panel control to the form.
			// Add the Label and TextBox controls to the Panel.
			panel1.Controls.Add(label1);
			panel1.Controls.Add(textBox1);
/*
*/
			this.Controls.Add(panel1);
		}// end drawPanel

		public void drawMenuBar (){
		this.Menu = new MainMenu();
        MenuItem item = new MenuItem("File");
        this.Menu.MenuItems.Add(item);
            item.MenuItems.Add("Save", new EventHandler(Save_Click));
            item.MenuItems.Add("Open", new EventHandler(Open_Click)); 
            item.MenuItems.Add("Page debug", new EventHandler(Debugging_Click)); 
        item = new MenuItem("Edit");
        this.Menu.MenuItems.Add(item);
            item.MenuItems.Add("Copy", new EventHandler(Copy_Click));
            item.MenuItems.Add("Paste", new EventHandler(Paste_Click)); 
        item = new MenuItem("View");
        this.Menu.MenuItems.Add(item);
            item.MenuItems.Add("WordWrap", new EventHandler(WordWrap_Click));
        item = new MenuItem("Navigation");
        this.Menu.MenuItems.Add(item);
            item.MenuItems.Add("Back", new EventHandler(Navigate_Back));
            item.MenuItems.Add("Forward", new EventHandler(Navigate_Forward));
            item.MenuItems.Add("Show History", new EventHandler(Show_History));
            //item.MenuItems.Add("Show Scroll Position", new EventHandler(GetScroll_Position));
        item = new MenuItem("Help");
        this.Menu.MenuItems.Add(item);
            item.MenuItems.Add("About", new EventHandler(About_Click));
	   }// end drawMenuBar

		//Menu 
		public void Show_History(object sender, EventArgs e) {
			string outString = "History - You are at: "+historyIndex+ Environment.NewLine;
			//string outString = "History: "+ Environment.NewLine;
/*
			for (int idnex = 0; idnex < 10; idnex++){
				outString += idnex + ": "+ history[idnex] + Environment.NewLine;
			}

*/			
			int idnex = 0;
			foreach (string hist in history){
				outString += idnex + ": "+ hist + Environment.NewLine;
				idnex++;
			}
			MessageBox.Show(outString);
		}// end Save_Click
		
		public void Navigate_Back(object sender, EventArgs e) {
			historyIndex--;
			// inputBox_PRNumber.Text = history[historyIndex];
			loadNewPage();
		}// end Save_Click
		
		public void Navigate_Forward(object sender, EventArgs e) {
			Array.Resize(ref history, history.Length + 1);
			historyIndex++;
			// inputBox_PRNumber.Text = history[historyIndex];
			loadNewPage();
		}// end Save_Click
		





//Connective functions.		
		public void Work_Search_Button_Click(object sender, EventArgs e) {
			//SetStatus(673,"Complete");
        }// end Approved_Button_Click
		
        public void Needs_Feedback_Button_Click(object sender, EventArgs e) {
			outBox_val.AppendText(Environment.NewLine + Clipboard.GetText());
        }// end Approved_Button_Click
		
        public void Add_Waiver_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string string_out = AddWaiver(PR);
			outBox_val.AppendText(Environment.NewLine + "Waiver: "+PR + " "+ string_out);
			//outBox_val.AppendText(Environment.NewLine + CannedMessage("AutoValEnd","testing testing 1..2..3."));
        }// end Approved_Button_Click
		
        public void Open_In_Browser_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string string_out = AddWaiver(PR);
			outBox_val.AppendText(Environment.NewLine + "Waiver: "+PR + " "+ string_out);
			//outBox_val.AppendText(Environment.NewLine + CannedMessage("AutoValEnd","testing testing 1..2..3."));
        }// end Approved_Button_Click
		
        public void Retry_Button_Click(object sender, EventArgs e) {
			string Path = "issues";
			string Type = "comments";
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string Url = GitHubApiBaseUrl+"/"+Path+"/"+PR+"/"+Type;
			string response_in = "";
			string response_out = "";
			string Body = "Test";//"@wingetbot waivers Add $Waiver"
			
			
			response_in = InvokeGitHubPRRequest(PR, "GET",Type,Body);
			foreach (System.Collections.Generic.Dictionary<string,object> item in FromJson(response_in)) {
				string myText; 
				myText = System.String.Format("created_at={0}, id={1}",item["created_at"], item["id"]); 
				response_out += "- response_list " + myText;//serializer.Serialize(item);
			}

			outBox_val.AppendText(Environment.NewLine + WebRequestMethods.Http.Get + " " +  Url + " - " + response_out);
        }// end Approved_Button_Click
		
        public void Approved_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string response_out = ApprovePR(PR);
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Approved_Button_Click
		
        public void Blocking_Issue_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			int response_out = ADOBuildFromPR(PR);
			outBox_val.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Check_Installer_Button_Click(object sender, EventArgs e) {
			outBox_val.AppendText(Environment.NewLine + InvokeGitHubRequest("https://api.github.com/rate_limit", WebRequestMethods.Http.Get,"",true));
        }// end Approved_Button_Click
		
        public void Project_File_Button_Click(object sender, EventArgs e) {
			outBox_val.AppendText(Environment.NewLine + webRequest("https://api.github.com/rate_limit", WebRequestMethods.Http.Get,"",true));
        }// end Approved_Button_Click
		
        public void Closed_Button_Click(object sender, EventArgs e) {
			outBox_val.AppendText(Environment.NewLine + Regex.IsMatch("test", "test").ToString());
        }// end Approved_Button_Click
		
        public void Defender_Fail_Button_Click(object sender, EventArgs e) {
			outBox_val.AppendText(Environment.NewLine + "TestPath: " + TestPath(StatusFile));
        }// end Approved_Button_Click
		
        public void Automation_Block_Button_Click(object sender, EventArgs e) {
			if (TestPath(StatusFile) == "File") {
				dynamic Records = FromCsv(GetContent(StatusFile));
				//var Records = csv.GetRecords<class_VMVersion>();
				outBox_val.AppendText(Environment.NewLine + "Records.Length: "+Records.Length);
				for (int r = 1; r < Records.Length -1; r++){
						outBox_val.AppendText(Environment.NewLine + "OS: " + Records[r]["OS"] + " - Version: " + Records[r]["Version"]);
				}
			}
        }// end Approved_Button_Click


        public void Installer_Not_Silent_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string response_out = ReplyToPR(PR,"ManValEnd");
			outBox_val.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Installer_Missing_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string response_out = CheckStandardPRComments(PR).ToString();
			outBox_val.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Needs_PackageUrl_Button_Click(object sender, EventArgs e) {
			outBox_val.AppendText(Environment.NewLine + InvokeGitHubRequest("https://api.github.com/rate_limit", WebRequestMethods.Http.Get,"",true));
        }// end Approved_Button_Click
		
        public void Manifest_One_Per_PR_Button_Click(object sender, EventArgs e) {
			outBox_val.AppendText(Environment.NewLine + InvokeGitHubRequest("https://api.github.com/rate_limit", WebRequestMethods.Http.Get,"",true));
        }// end Approved_Button_Click
		
        public void Merge_Conflicts_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			int response_out = ADOBuildFromPR(PR);
			outBox_val.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Network_Blocker_Button_Click(object sender, EventArgs e) {
			outBox_val.AppendText(Environment.NewLine + GetVMVersion().ToString());
        }// end Approved_Button_Click
		
		//Modes
        public void Approving_Button_Click(object sender, EventArgs e) {
			string Status = "Approving";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Approved_Button_Click
		
        public void IEDS_Button_Click(object sender, EventArgs e) {
			string Status = "IEDS";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Approved_Button_Click
		
        public void Validating_Button_Click(object sender, EventArgs e) {
			string Status = "Validating";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Approved_Button_Click
		
        public void Idle_Button_Click(object sender, EventArgs e) {
			string Status = "Idle";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Approved_Button_Click

        public void Config_Button_Click(object sender, EventArgs e) {
			string Status = "Idle";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Approved_Button_Click






//Misc Data
public string[] StandardPRComments = {"Validation Pipeline Badge",//Pipeline status
"wingetbot run",//Run pipelines
"azp run",//Run pipelines
"AzurePipelines run",//Run pipelines
"Azure Pipelines successfully started running 1 pipeline",//Run confirmation
"The check-in policies require a moderator to approve PRs from the community",//Validation complete 
"microsoft-github-policy-service agree",//CLA acceptance
"wingetbot waivers Add",//Any waivers
"The pull request encountered an internal error and has been assigned to a developer to investigate",//IEDS or other error
"Manifest Schema Version: 1.4.0 less than 1.5.0 for ID:",//Manifest depreciation for 1.4.0
"This account is bot account and belongs to CoolPlayLin",//CoolPlayLin's automation
"This account is automated by Github Actions and the source code was created by CoolPlayLin",//Exorcism0666's automation
"Response status code does not indicate success",//My automation - removal PR where URL failed status check.
"Automatic Validation ended with",//My automation - Validation output might be immaterial if unactioned.
"Manual Validation ended with",//My automation - Validation output might be immaterial if unactioned.
"No errors to post",//My automation - AutoValLog with no logs.
"The package didn't pass a Defender or similar security scan",//My automation - DefenderFail.
"Installer failed security check",//My automation - AutoValLog DefenderFail.
"Sequence contains no elements"//New Sequence error.
};

public string[] WordFilterList = {"accept_gdpr ", 
"accept-licenses", 
"accept-license", 
"eula",
"downloadarchive.documentfoundation.org"
};

public string[] CountrySet = {"Default",
"Warm","Cool","Random","Afghanistan","Albania","Algeria","American Samoa","Andorra","Angola","Anguilla","Antigua And Barbuda","Argentina","Armenia","Aruba","Australia","Austria","Azerbaijan","Bahamas","Bahrain","Bangladesh","Barbados","Belarus","Belgium","Belize","Benin","Bermuda","Bhutan","Bolivia","Bosnia And Herzegovina","Botswana","Bouvet Island","Brazil","Brunei Darussalam","Bulgaria","Burkina Faso","Burundi","Cabo Verde","Cambodia","Cameroon","Canada","Central African Republic","Chad","Chile","China","Colombia","Comoros","Cook Islands","Costa Rica","Croatia","Cuba","Curacao","Cyprus","Czechia","CÃ¶te D'Ivoire","Democratic Republic Of The Congo","Denmark","Djibouti","Dominica","Dominican Republic","Ecuador","Egypt","El Salvador","Equatorial Guinea","Eritrea","Estonia","Eswatini","Ethiopia","Fiji","Finland","France","French Polynesia","Gabon","Gambia","Georgia","Germany","Ghana","Greece","Grenada","Guatemala","Guinea","Guinea-Bissau","Guyana","Haiti","Holy See (Vatican City State)","Honduras","Hungary","Iceland","India","Indonesia","Iran","Iraq","Ireland","Israel","Italy","Jamaica","Japan","Jordan","Kazakhstan","Kenya","Kiribati","Kuwait","Kyrgyzstan","Laos","Latvia","Lebanon","Lesotho","Liberia","Libya","Liechtenstein","Lithuania","Luxembourg","Madagascar","Malawi","Malaysia","Maldives","Mali","Malta","Marshall Islands","Mauritania","Mauritius","Mexico","Micronesia","Moldova","Monaco","Mongolia","Montenegro","Morocco","Mozambique","Myanmar","Namibia","Nauru","Nepal","Netherlands","New Zealand","Nicaragua","Niger","Nigeria","Niue","Norfolk Island","North Korea","North Macedonia","Norway","Oman","Pakistan","Palau","Palestine","Panama","Papua New Guinea","Paraguay","Peru","Philippines","Pitcairn Islands","Poland","Portugal","Qatar","Republic Of The Congo","Romania","Russian Federation","Rwanda","Saint Kitts And Nevis","Saint Lucia","Saint Vincent And The Grenadines","Samoa","San Marino","Sao Tome And Principe","Saudi Arabia","Senegal","Serbia","Seychelles","Sierra Leone","Singapore","Slovakia","Slovenia","Solomon Islands","Somalia","South Africa","South Korea","South Sudan","Spain","Sri Lanka","Sudan","Suriname","Sweden","Switzerland","Syrian Arab Republic","Tajikistan","Tanzania"," United Republic Of","Thailand","Togo","Tonga","Trinidad And Tobago","Tunisia","Turkey","Turkmenistan","Tuvalu","Uganda","Ukraine","United Arab Emirates","United Kingdom","United States","Uruguay","Uzbekistan","Vanuatu","Venezuela","Vietnam","Yemen","Zambia","Zimbabwe","Ã…land Islands"
};

public string[] MagicStrings = {"Installer Verification Analysis Context Information:", //0
"[error] One or more errors occurred.", //1
"[error] Manifest Error:", //2
"BlockingDetectionFound", //3
"Processing manifest", //4
"SQL error or missing database", //5
"Error occurred while downloading installer" //6
};

public string[] MagicLabels = {"Validation-Defender-Error", //0
"Binary-Validation-Error", //1
"Error-Analysis-Timeout", //2
"Error-Hash-Mismatch", //3
"Error-Installer-Availability", //4
"Internal-Error", //5
"Internal-Error-Dynamic-Scan", //6
"Internal-Error-Manifest", //7
"Internal-Error-URL", //8
"Manifest-AppsAndFeaturesVersion-Error", //9
"Manifest-Installer-Validation-Error", //10
"Manifest-Validation-Error", //11
"Possible-Duplicate", //12
"PullRequest-Error", //13
"URL-Validation-Error", //14
"Validation-Domain", //15
"Validation-Executable-Error", //16
"Validation-Hash-Verification-Failed", //17
"Validation-Missing-Dependency", //18
"Validation-Merge-Conflict", //19
"Validation-No-Executables", //20
"Validation-Installation-Error", //21
"Validation-Shell-Execute", //22
"Validation-Unattended-Failed", //23
"Policy-Test-1.2", //24
"Policy-Test-2.3", //25
"Validation-Completed", //26
"Validation-Forbidden-URL-Error", //27
"Validation-Unapproved-URL", //28
"Validation-Retry", //29
"Needs-Author-Feedback",//30
"Policy-Test-2.3" //31
};




    }// end WinGetApprovalPipeline
}// end WinGetApprovalNamespace


/* Original drawing
................................................................................................................................................................................................................................................
WinGet Approver - Build 365
....VMs.....................................................................................................................................................................................................................................
....................................................................................................................|......--------------------......--------------------......---------------------------------------------.....
....VM..|.Status.|.Version.|.OS.|.Package.|.PR.|.RAM.............................|......|...Blocking...|......|..Feedback..|.....|..................139040....................|.....
....600.|.Ready.|.99.....|.Win10..|.............|.......|......................................|......|___Issue___|.....|__________|.....|_________________________|......
....601.|.Ready.|.99.....|.Win10..|.............|.......|......................................|......--------------------......--------------------......--------------------......--------------------.....
....602.|.Ready.|.99.....|.Win10..|.............|.......|......................................|......|......Retry.....|......|...Changes....|.....|.....Check....|.....|...Approved..|.....
....603.|.Ready.|.99.....|.Win10..|.............|.......|......................................|......|__________|......|_Requested_|.....|__Installer_|.....|__________|.....
....604.|.Ready.|.99.....|.Win10..|.............|.......|......................................|......--------------------......--------------------......--------------------......--------------------.....
....605.|.Ready.|.99.....|.Win10..|.............|.......|......................................|......|....Waiver....|......|.....Squash....|.....|.....Project....|.....|.....Closed....|.....
....................................................................................................................|......|__________|......|__________|......|__________|.....|__________|.....
__________________________________________________________|_____________________________________________________________
....Approvals............................................................................................................................................................................................................................
.................................................................................................................................................................................................................................................
|.Timestp..|.PR#.......|.PackageIdentifier......................|.prVersion........|.A.|.R.|.W.|.F.|.I.|.D.|.V.|.ManifestVer.........|.OK.|..........................................
|.15:18:10.|.138430.|.JetBrains.WebStorm.EAP..........|.241.11761.28..|.A.|.R.|.W.|.1.|.I.|.D.|.999.|.241.10840.2......|.OK.|..........................................
|.15:18:18.|.138431.|.Fly-io.flyctl.................................|.0.1.148............|.A.|.R.|.W.|.0.|.I.|.D.|.999.|.0.1.147..............|.OK.|.........................................
|.15:18:32.|.138435.|.JosephFinney.Text-Grab...........|.4.1.3.................|.A.|.R.|.W.|.0.|.I.|.D.|.999.|.4.1.0..................|.OK.|.........................................
|.15:18:42.|.138437.|.AdGuard.AdGuardVPN..............|.2.2.1251.0.......|.A.|.R.|.W.|.0.|.-.|.D.|.999.|.2.2.1233.0.........|.OK.|.........................................
|.15:18:52.|.138438.|.VSCodium.VSCodium.Insiders..|.1.86.0.24039....|.A.|.R.|.W.|.0.|.I.|.D.|.999.|.1.86.0.24038.....|.OK.|.........................................
|.15:19:31.|.138440.|.Rustlang.Rust.MSVC...................|.1.76.0..............|.+.|.R.|.W.|.1.|.I.|.D.|.999.|.1.75.0................|.OK.|........................................
|.15:19:48.|.138441.|.Rustlang.Rust.GNU.....................|.1.76.0..............|.+.|.R.|.W.|.1.|.I.|.D.|.999.|.1.75.0................|.OK.|........................................
________________________________________________________________________________________________________________________
......--------------------......--------------------......--------------------......--------------------......--------------------......--------------------......--------------------......--------------------.....
......|..Approving.|......|.......IEDS......|.....|.......Idle.......|.....|..Validating..|.....|.....Button....|......|.....Button....|.....|.....Button....|.....|......Reset.....|.....
......|__________|......|__________|......|__________|.....|__________|......|__________|......|__________|......|__________|.....|__Vedant__|.....
......--------------------......--------------------......--------------------......--------------------......--------------------......--------------------......--------------------......--------------------.....
......|...Installer...|......|....Installer...|......|.....Merge....|.....|...Network..|.....|One.Manifest|......|...Package...|.....|WorkSearch.|.....|..Timeclock..|.....
......|_Not_Silent|......|__Missing__|.....|_Conflicts__|.....|__Blocker__|......|__Per_PR___|......|___Url____|......|__________|.....|__________|.....
......--------------------......--------------------......--------------------......--------------------......--------------------......--------------------......--------------------......--------------------.....
......|..Defender..|......|.Automation|.....|.....Button....|.....|.....Button....|.....|.....Button....|......|.....Button....|.....|.....Button....|.....|.....Button....|.....
......|___Fail____|......|___Block___|.....|__________|.....|__________|......|__________|......|__________|......|__________|.....|__________|.....
................................................................................................................................................................................................................................................
................................................................................................................................................................................................................................................
*/
