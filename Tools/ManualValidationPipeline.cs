//Copyright 2022-2024 Microsoft Corporation
//Author: Stephen Gillie
//Title: WinGet Approval Pipeline v3.-40.1
//Created: 1/19/2024
//Updated: 3/21/2024
//Notes: Tool to streamline evaluating winget-pkgs PRs. 
//Update log:
//3.-38.0 - Port WorkSearch 75%.
//3.-39.1 - Add RetryPR to centralize these lines.
//3.-39.0 - Port LabelAction.
//3.-40.2 - Complete porting LineFromCommitFile.
//3.-40.1 - Complete porting PRStateFromComments.






/*Contents: (Remaining functions to port or depreciate: 31)
- Init vars
- Boilerplate
- UI top-of-box
	- Menu
- Tabs (2)
- Automation Tools (2)
- PR tools (1)
- Network tools
- Validation Starts Here (6)
- Manifests Etc (5)
- VM Image Management (3)
- VM Pipeline Management (5)
- VM Status (1)
- VM Versioning
- VM Orchestration (2)
- File Management
- Inject into files on disk
- Inject into PRs
- Reporting
- Clipboard
- Etc (1)
- PR Watcher Utility functions
- Powershell equivalency (+8)
- VM Window management (3)
- Misc data (+5)

Et cetera:
- PR counters on certain buttons - Approval-Ready, ToWork, Defender, IEDS
- VM control buttons
- Better way to display VM/Validation lists.
- CLI switches such as --hourly-run
*/





/*
Partial (7): 
CheckStandardPRComments needs work on data structures. 
Get-TrackerVMWindowLoc
Get-TrackerVMWindowSet
Get-TrackerVMWindowArrange#Get-TrackerVMWindowSet, Get-TrackerVMWindowLoc
AddValidationData
WorkSearch

#Todo:

#Blocked:
Get-ManifestListing#Find-WinGetPackage
	Get-ListingDiff#Get-ManifestListing

Get-TrackerVMRebuildStatus#Get-VM
Get-TrackerVMRevert#Restore-VMCheckpoint
Stop-TrackerVM#Stop-VM
Complete-TrackerVM#Stop-TrackerVM

Redo-Checkpoint#Checkpoint-VM, Remove-VMCheckpoint
Get-ImageVMStop#Redo-Checkpoint, Stop-TrackerVM
Get-ImageVMStart#Get-TrackerVMRevert, Start-VM
Get-PipelineVmDisgenerate#Remove-VM, Stop-TrackerVM

Get-ImageVMMove#Get-VM, Move-VMStorage, Rename-VM

Get-PipelineVmGenerate#Get-TrackerVMRevert, Get-VM, Import-VM, Remove-VMCheckpoint, Rename-VM, Start-VM
	Get-TrackerVMCycle#Complete-TrackerVM, Get-PipelineVmDisgenerate, Get-PipelineVmGenerate, Redo-Checkpoint
	Get-TrackerVMValidate#Find-WinGetPackage, Get-PipelineVmGenerate,  Get-TrackerVMRevert,  Get-VM
		Get-TrackerVMValidateByID#Get-TrackerVMValidate
		Get-TrackerVMValidateByConfig#Get-TrackerVMValidate
		Get-TrackerVMValidateByArch#Get-TrackerVMValidate
		Get-TrackerVMValidateByScope#Get-TrackerVMValidate
		Get-TrackerVMValidateBothArchAndScope#Get-TrackerVMValidate
		Get-ManifestFile#Get-TrackerVMValidate
			Get-ManifestAutomation#Get-ManifestFile
			Get-SingleFileAutomation#Get-ManifestFile, Get-ManifestListing
			Get-RandomIEDS#Get-ManifestFile
			Get-TrackerVMRunTracker#Get-RandomIEDS, Get-TrackerVMCycle, Get-TrackerVMValidate, Get-TrackerVMWindowArrange, Get-VM, Set-VM
		Get-PRWatch#Find-WinGetPackage, Get-ListingDiff, Get-TrackerVMValidate

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
using System.IO.Compression;
using System.Linq;
using System.Management;
using System.Net;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;
using System.Web.Script.Serialization;

namespace WinGetApprovalNamespace {
    public class WinGetApprovalPipeline : Form {
		//vars
        public int build = 445;//Get-RebuildPipeApp	
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
		
		//ADOLogs - should be refactored to be in-memory.
		public static string DestinationPath = MainFolder+"\\Installers";
		public static string LogPath = DestinationPath+"\\InstallationVerificationLogs\\";
		public static string ZipPath = DestinationPath+"\\InstallationVerificationLogs.zip";

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
		JavaScriptSerializer serializer = new JavaScriptSerializer();//JSON

		//ui
		public RichTextBox outBox = new RichTextBox();
		public RichTextBox outBox_val, outBox_vm;
		public System.Drawing.Bitmap myBitmap;//Depreciate
		public System.Drawing.Graphics pageGraphics;//Depreciate?
		public Panel pagePanel;
		public ContextMenuStrip contextMenu1;//Menu?

		public TextBox inputBox_PRNumber, inputBox_User, inputBox_VMRAM;
 		public Label label_VMRAM = new Label();
        public Button btn0, btn1, btn2, btn3, btn4, btn5, btn6, btn7, btn8, btn9;
        public Button btn10, btn11, btn12, btn13, btn14, btn15, btn16, btn17, btn18, btn19;
        public Button btn20, btn21, btn22, btn23, btn24, btn25, btn26, btn27, btn28;
		
		int DarkMode = 1;//(int)Microsoft.Win32.Registry.GetValue("HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize", "AppsUseLightTheme", -1);
		//0 : dark theme
		//1 : light theme
		//-1 : AppsUseLightTheme could not be found
		
		public Color color_DefaultBack = Color.FromArgb(240,240,240);
		public Color color_DefaultText = Color.FromArgb(0,0,0);
		public Color color_InputBack = Color.FromArgb(255,255,255);
		public Color color_ActiveBack = Color.FromArgb(200,240,240);

		//Grid
		public static int gridItemWidth = 70;
		public static int gridItemHeight = 45;

		public int lineHeight = 14;
		public int WindowWidth = gridItemWidth*10+10;
		public int WindowHeight = gridItemHeight*12+10;
		
		//Fonts
		string AppFont = "Calibri";
		int AppFontSIze = 12;
		int urlBoxFontSIze = 14;
		string buttonFont = SystemFonts.MessageBoxFont.ToString();
		int buttonFontSIze = 8;

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
			//this.StartPosition = FormStartPosition.CenterScreen;
			this.FormBorderStyle = FormBorderStyle.FixedSingle;

			this.MaximizeBox = false;
			//this.MinimizeBox = false;
			//this.Resize += new System.EventHandler(this.OnResize);
			this.AutoScroll = true;
			this.Icon = Icon.ExtractAssociatedIcon(System.Reflection.Assembly.GetExecutingAssembly().Location);
			Array.Resize(ref history, history.Length + 2);
			history[historyIndex] = "about:blank";
			historyIndex++;
			
		if (DarkMode == 0) {
			color_DefaultBack = Color.FromArgb(15,15,15);
			color_DefaultText = Color.FromArgb(255,255,255);
			color_ActiveBack = Color.FromArgb(15,55,105);
			color_InputBack = Color.FromArgb(0,0,0);
		}
			this.BackColor = color_DefaultBack;
			this.ForeColor = color_DefaultText;
			
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
			button.BackColor = color_DefaultBack;
			button.ForeColor = color_DefaultText;
			button.Click += new EventHandler(buttonOnclick);
			button.Font = new Font(buttonFont, buttonFontSIze);
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
			outBox.BackColor = color_DefaultBack;
			outBox.ForeColor = color_DefaultText;
			outBox.Font = new Font(AppFont, AppFontSIze);
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
			urlBox.Font = new Font(AppFont, urlBoxFontSIze);
			urlBox.Location = new Point(pointX, pointY);
			urlBox.BackColor = color_InputBack;
			urlBox.ForeColor = color_DefaultText;
			urlBox.Width = sizeX;
			urlBox.Height = sizeY;
			urlBox.KeyUp += urlBox_KeyUp;
			Controls.Add(urlBox);
		}
		
		public void drawLabel(ref Label newLabel, int pointX, int pointY, int sizeX, int sizeY,string text){
			newLabel = new Label();
			newLabel.BorderStyle = System.Windows.Forms.BorderStyle.Fixed3D;
			//newLabel.ImageList = imageList1;
			newLabel.ImageIndex = 1;
			newLabel.ImageAlign = ContentAlignment.TopLeft;
			newLabel.BackColor = color_DefaultBack;
			newLabel.ForeColor = color_DefaultText;
			newLabel.Name = "newLabel";
			newLabel.Font = new Font(AppFont, AppFontSIze);
			newLabel.Location = new Point(pointX, pointY);
			newLabel.Width = sizeX;
			newLabel.Height = sizeY;
			//newLabel.KeyUp += newLabel_KeyUp;

			newLabel.Text = text;

			//newLabel.Size = new Size (label1.PreferredWidth, label1.PreferredHeight);
			Controls.Add(newLabel);
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
 			int row10 = gridItemHeight*inc;inc++;
 			
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
 			drawButton(ref btn3, col7, row0, gridItemWidth, gridItemHeight, "Approval Search", Open_In_Browser_Button_Click);
			drawUrlBox(ref inputBox_PRNumber,col8, row0, gridItemWidth*2,gridItemHeight,"#000000");
 			
			drawButton(ref btn27, col6, row1, gridItemWidth, gridItemHeight, "ToWork Search", Work_Search_Button_Click); 
 			drawButton(ref btn4, col7, row1, gridItemWidth, gridItemHeight, "Retry", Retry_Button_Click);
 			drawButton(ref btn5, col8, row1, gridItemWidth, gridItemHeight, "Approved", Approved_Button_Click);
 			drawButton(ref btn7, col9, row1, gridItemWidth, gridItemHeight, "Manually Validated", Manually_Validated_Button_Click);
 			
 			drawButton(ref btn9, col6, row2, gridItemWidth, gridItemHeight, "Closed (disabled)", Closed_Button_Click);
			drawButton(ref btn26, col7, row2, gridItemWidth, gridItemHeight, "Merge Conflicts", Merge_Conflicts_Button_Click);
 			drawButton(ref btn14, col8, row2, gridItemWidth, gridItemHeight, "Duplicate", Duplicate_Button_Click);
 			drawButton(ref btn13, col9, row2, gridItemWidth, gridItemHeight, "Check Installer", Check_Installer_Button_Click);
 			
			drawButton(ref btn24, col6, row3, gridItemWidth, gridItemHeight, "Needs PackageUrl", Needs_PackageUrl_Button_Click);
 			drawButton(ref btn15, col7, row3, gridItemWidth, gridItemHeight, "Automation Block", Automation_Block_Button_Click);
 			drawButton(ref btn16, col8, row3, gridItemWidth, gridItemHeight, "Installer Not Silent", Installer_Not_Silent_Button_Click);
 			drawButton(ref btn17, col9, row3, gridItemWidth, gridItemHeight, "Installer Missing", Installer_Missing_Button_Click);
			
			drawButton(ref btn25, col6, row4, gridItemWidth, gridItemHeight, "Manifest One Per PR", Manifest_One_Per_PR_Button_Click);
 			drawButton(ref btn6, col7, row4, gridItemWidth, gridItemHeight, "Driver Install", Driver_Install_Button_Click);
 			drawButton(ref btn8, col8, row4, gridItemWidth, gridItemHeight, "Project", Project_File_Button_Click);
			drawButton(ref btn2, col9, row4, gridItemWidth, gridItemHeight, "Squash", Squash_Button_Click);
			
			drawLabel(ref label_VMRAM, col0, row5, gridItemWidth, gridItemHeight,"VM RAM:");
			drawUrlBox(ref inputBox_VMRAM,col1, row5, gridItemWidth*2,gridItemHeight,"");//UserInput field 
			drawUrlBox(ref inputBox_User,col8, row5, gridItemWidth*2,gridItemHeight,"");//UserInput field 
			
			drawOutBox(ref outBox_val, col0, row6, this.ClientRectangle.Width,gridItemHeight*4, "", "outBox_val");
			
 			drawButton(ref btn10, col0, row10, gridItemWidth, gridItemHeight, "Bulk Approving", Approving_Button_Click);
			drawButton(ref btn18, col1, row10, gridItemWidth, gridItemHeight, "Individual Validations", Validating_Button_Click);
 			drawButton(ref btn11, col2, row10, gridItemWidth, gridItemHeight, "Validate Rand IEDS", IEDS_Button_Click);
			drawButton(ref btn19, col3, row10, gridItemWidth, gridItemHeight, "Idle Mode", Idle_Button_Click);
			drawButton(ref btn20, col4, row10, gridItemWidth, gridItemHeight, "Config (disabled)", Config_Button_Click);
			

 	  }// end drawGoButton

		public void OnResize(object sender, System.EventArgs e) {
			//outBox.Height = ClientRectangle.Height - gridItemHeight;
			//outBox.Width = ClientRectangle.Width - 0;
			//inputBox_PRNumber.Width = ClientRectangle.Width - gridItemWidth*2;
			//btn1.Left = ClientRectangle.Width/4;
		}

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
			
			//inputBox_User.Text = GetMode();
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
public void WorkSearch(int Days = 7) {
string[] PresetList = {"Approval","ToWork"};
	foreach (string Preset in PresetList) {
		int Count= 30;
		int Page = 1;
		while (Count == 30) {
			int line = 0;
			Dictionary<string,dynamic>[] PRs = SearchGitHub(Preset,Page,Days,false,true);

			Count = PRs.Length; //if fewer than 30 PRs (1 page) are returned, then complete the loop and continue instead of starting another loop.
			PRs = PRs.Where(n => n["labels"] != null).ToArray();//.Where(n => n["number"] -notin (Get-Status).pr} 
			
			foreach (Dictionary<string,dynamic>FullPR in PRs) {
				int PR = FullPR["number"];
				//Get-TrackerProgress -PR $PR $MyInvocation.MyCommand line PRs.Length
				line++;
				if((FullPR["title"].Contains("Remove")) || 
				(FullPR["title"].Contains("Delete")) || 
				(FullPR["title"].Contains("Automatic deletion"))){
					//Get-GitHubPreset CheckInstaller -PR $PR
				}
				dynamic Comments = InvokeGitHubPRRequest(PR,"comments");
				if (Preset == "Approval"){
					if (CheckStandardPRComments(PR,Comments)){
						OpenPRInBrowser(PR);
					} else {
						OpenPRInBrowser(PR,true);
					}
				} else if (Preset == "Defender"){
					LabelAction(PR);
				} else {//ToWork etc
/*
					$Comments = ($Comments | select created_at,@{n="UserName";e={$_.user.login.Replace("\\[bot\\]")}},body)
					State = (Get-PRStateFromComments -PR $PR -Comments $Comments)
					$LastState = $State[-1]
					if ($LastState.event == "DefenderFail") { 
						Get-PRLabelAction -PR $PR
					} else if ($LastState.event == "LabelAction") { 
						Get-GitHubPreset -Preset LabelAction -PR $PR
						OpenPRInBrowser(PR);
					} else {
						if ($Comments[-1].UserName != $GitHubUserName) {
							OpenPRInBrowser(PR);
						}
					}//end if LastCommenter
*/
				}//end if Preset
			}//end foreach FullPR
			Page++;
		}//end While Count
	}//end foreach Preset
}//end Get-WorkSearch






//Automation Tools
		public void LabelAction(int PR){
		string[] PRLabels = FromJson(InvokeGitHubPRRequest(PR,"labels","content"))["name"];
			//Write-Output "PR $PR has labels $PRLabels"
			if (PRLabels.Any(n => MagicLabels[0].Contains(n))) {
				List<string> PRState = PRStateFromComments(PR);
		/*
				if (($PRState.Where(n => n.event == "PreValidation"})[-1].created_at < (Get-Date).AddHours(-8) && //Last Prevalidation was 8 hours ago.
				($PRState.Where(n => n.event == "Running"})[-1].created_at < (Get-Date).AddHours(-18)) {  //Last Run was 18 hours ago.
					Get-GitHubPreset Retry -PR $PR
				}
		*/
			} else {
				
				foreach (string Label in PRLabels) {
					string UserInput = "";
					if (Label == MagicLabels[1]) {
						UserInput = LineFromCommitFile(PR,36,MagicStrings[0],10);
						if (UserInput == null) {
							UserInput = LineFromCommitFile(PR,41,MagicStrings[0],10);
						}
						if (UserInput == null) {
							UserInput = LineFromCommitFile(PR,50,MagicStrings[0],10);
						}
						if (UserInput == null) {
							UserInput = LineFromCommitFile(PR,26,MagicStrings[0],10);
						}
						if (UserInput == null) {
							UserInput = LineFromCommitFile(PR,34,MagicStrings[0],10);
						}
						if (UserInput != null) {
							ReplyToPR(PR,"AutoValEnd",UserInput);
						}
						if (UserInput.Contains(MagicStrings[3])) {
							AddPRToRecord(PR,"Blocking");
							ReplyToPR(PR,"AutomationBlock","","Network-Blocker");
						}
					} else if (Label == MagicLabels[2]) {
							UserInput = LineFromCommitFile(PR,36,MagicStrings[0],3);
							if (UserInput == null) {
								ReplyToPR(PR,"AutoValEnd",UserInput);
							}
							if (UserInput.Contains(MagicStrings[3])) {
								AddPRToRecord(PR,"Blocking");
								ReplyToPR(PR,"AutomationBlock","","Network-Blocker");
							}
						} else if (Label == MagicLabels[3]) {
							UserInput = LineFromCommitFile(PR,36,MagicStrings[0],10);
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,26,MagicStrings[0],10); 
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,36,MagicStrings[0],10); 
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,37,MagicStrings[0],10); 
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,50,MagicStrings[0],10); 
							}
							if (UserInput == null) {
								ReplyToPR(PR,"AutoValEnd",UserInput);
								//Get-UpdateHashInPR2 -PR $PR -Clip UserInput
							}
						} else if (Label == MagicLabels[4]) { 
							UserInput = LineFromCommitFile(PR,36,MagicStrings[6],5);
							if (UserInput == null) {
								ReplyToPR(PR,"AutoValEnd",UserInput);
								//Get-GitHubPreset -PR $PR -Preset CheckInstaller
							}
						} else if (Label == MagicLabels[5]) {
							UserInput = LineFromCommitFile(PR,25,MagicStrings[1]);
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,15,MagicStrings[1]);
							}
							if (UserInput == null) {
								if (UserInput.Contains(MagicStrings[5])) {
									RetryPR(PR);
								}
								ReplyToPR(PR,"AutoValEnd",UserInput);
							}
						} else if (Label == MagicLabels[6]) {
							RetryPR(PR);
						} else if (Label == MagicLabels[7]) {
							UserInput = LineFromCommitFile(PR,15,MagicStrings[1]);
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,25,MagicStrings[4],7);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,39,MagicStrings[4],7);
							}
							if (UserInput == null) {
								if (UserInput.Contains("Sequence contains no elements")) {//Reindex fixes this.
									ReplyToPR(PR,"SequenceNoElements");

									string PRtitle = FromJson(InvokeGitHubPRRequest(PR,""))["title"];
									if ((PRtitle.Contains("Automatic deletion")) || (PRtitle.Contains("Remove"))) {
										ReplyToPR(PR,"","","Manually-Validated","This package installs and launches normally on a Windows 10 VM.");
									}
								}
							}
						} else if (Label == MagicLabels[8]) {
							UserInput = LineFromCommitFile(PR,25,MagicStrings[1]);
							if (UserInput == null) {
								if (UserInput.Contains(MagicStrings[5])) {
									RetryPR(PR);
								}
								ReplyToPR(PR,"AutoValEnd",UserInput);
							}
						} else if (Label == MagicLabels[9]) {
							UserInput = LineFromCommitFile(PR,25,MagicStrings[2]);
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,25,MagicStrings[1]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,15,MagicStrings[2]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,15,MagicStrings[1]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,39,MagicStrings[2]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,39,MagicStrings[1]);
							}
							if (UserInput == null) {
								ReplyToPR(PR,"AutoValEnd",UserInput);
							}
						} else if (Label == MagicLabels[10]) {
							UserInput = LineFromCommitFile(PR,25,MagicStrings[2]);
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,25,MagicStrings[1]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,31,MagicStrings[2]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,31,MagicStrings[1]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,44,MagicStrings[2]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,44,MagicStrings[1]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,15,MagicStrings[2]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,15,MagicStrings[1]);
							}
							if (UserInput == null) {
								ReplyToPR(PR,"AutoValEnd",UserInput);
							}
						} else if (Label == MagicLabels[11]) {//Manifest-Validation-Error
							UserInput = LineFromCommitFile(PR,25,MagicStrings[2]);
							if (null == UserInput) {
								UserInput = LineFromCommitFile(PR,25,MagicStrings[1]);
							}
							if (null == UserInput) {
								UserInput = LineFromCommitFile(PR,31,MagicStrings[2]);
							}
							if (null == UserInput) {
								UserInput = LineFromCommitFile(PR,31,MagicStrings[1]);
							}
							if (null == UserInput) {
								UserInput = LineFromCommitFile(PR,44,MagicStrings[2]);
							}
							if (null == UserInput) {
								UserInput = LineFromCommitFile(PR,44,MagicStrings[1]);
							}
							if (null == UserInput) {
								UserInput = LineFromCommitFile(PR,15,MagicStrings[2]);
							}
							if (null == UserInput) {
								UserInput = LineFromCommitFile(PR,15,MagicStrings[1]);
							}
							if (null != UserInput) {
								ReplyToPR(PR,"AutoValEnd",UserInput);
							}
						} else if (Label == MagicLabels[12]) {
							//Get-GitHubPreset PossibleDuplicate -PR PR
						} else if (Label == MagicLabels[13]) {
							UserInput = LineFromCommitFile(PR,24,MagicStrings[1]);
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,25,MagicStrings[1]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,14,MagicStrings[1]);
							}
							if (UserInput == null) {
								UserInput = LineFromCommitFile(PR,27,MagicStrings[1]);
							}
							if (UserInput.Contains("The pull request contains more than one manifest")) {
								AddPRToRecord(PR,"Feedback");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
								ReplyToPR(PR,"OneManifestPerPR",MagicLabels[30]);
							}
							if (UserInput == null) {
								ReplyToPR(PR,"AutoValEnd",UserInput);
							}
						} else if (Label == MagicLabels[14]) {
							UserInput = LineFromCommitFile(PR,32,"Validation result: Failed");
							//Get-GitHubPreset -PR PR -Preset CheckInstaller
							if (UserInput == null) {
								ReplyToPR(PR,"AutoValEnd",UserInput);
							}
						} else if (Label == MagicLabels[15]) {
						} else if (Label == MagicLabels[16]) {
							AutoValLog(PR);
						} else if (Label == MagicLabels[17]) {
							AutoValLog(PR);
						} else if (Label == MagicLabels[18]) {
							UserInput = LineFromCommitFile(PR,25,MagicStrings[1]);
							if (UserInput == null) {
								ReplyToPR(PR,"AutoValEnd",UserInput);
							}
						} else if (Label == MagicLabels[19]) {
						} else if (Label == MagicLabels[20]) {
							string PRtitle = FromJson(InvokeGitHubPRRequest(PR,""))["title"];
							foreach (Dictionary<string,object> Waiver in GetValidationData("autoWaiverLabel")) {
								if (PRtitle.Contains((string)Waiver["PackageIdentifier"])) {
									AddWaiver(PR);
								}
							}
						} else if (Label == MagicLabels[21]) {
							AutoValLog(PR);
						} else if (Label == MagicLabels[22]) {
							AutoValLog(PR);
						} else if (Label == MagicLabels[23]) {
							AutoValLog(PR);
					}//end if Label
				}//end foreach Label
			}//end if Label
		}


		public string AddWaiver(int PR) {
			dynamic Labels = FromJson(InvokeGitHubPRRequest(PR ,WebRequestMethods.Http.Get,"labels","","issues"));
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
					string_out += InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","@wingetbot waivers Add "+Waiver,"issues");
				}; //end if Waiver
			}; //end Foreach Label
			return string_out;
		} //end Add-Waiver

								//SearchGitHub(string Preset, int Page = 1, int Days = 0, bool IEDS = false, bool NoLabels = false, bool Browser = false)
		public dynamic SearchGitHub(string Preset, int Page = 1,int Days = 0,bool IEDS = false,bool NoLabels = false,bool Browser = false){
		//[ValidateSet("Approval","Blocking","Defender","IEDS","ToWork","ToWork2")]
		string Url = "https://api.github.com/search/issues?page=Page&q=";
			if (Browser == true) {
				Url = GitHubBaseUrl+"/pulls?page=Page&q=";
			}
			//Base settings;
			string Base = "repo:"+owner+"/"+repo+"+";
			Base += "is:pr+";
			//if (AllowClosedPRs == false) {
				Base += "is:open+";
			//}
			Base += "draft:false+";
			
			//Smaller blocks;
			string nApproved = "-label:Moderator-Approved+";
			string string_nBI = "-label:Blocking-Issue+";
			string Defender = "label:"+MagicLabels[0]+"+";
			string HaventWorked = "-commenter:"+GitHubUserName+"+";
			string string_nHW = "-label:Hardware+";
			string IEDSLabel = "label:Internal-Error-Dynamic-Scan+";
			string nIEDS = "-"+IEDSLabel;
			string string_IEM = "label:Internal-Error-Manifest+";
			string string_NA = "label:Needs-Attention+";
			string string_NAF = "label:Needs-Author-Feedback+";
			string nNSA = "-label:Internal-Error-NoSupportedArchitectures+";
			string NotPass = "-label:Azure-Pipeline-Passed+";//Hasn't passed pipelines;
			//string SortUp = "sort:updated-asc+";
			string string_VC = "label:Validation-Completed+";//Completed;
			//string string_VPM = "label:Version-Parameter-Mismatch+";
			string string_nVC = "-"+string_VC;//Completed;

			string date = DateTime.Now.AddDays(-Days).ToString("yyyy-MM-dd");
			string Recent = "updated:>"+date+"+";
			
			//Building block settings;
			string Blocking = string_nHW;
			Blocking += nNSA;
			Blocking += "-label:DriverInstall+";
			Blocking += "-label:Agreements+";
			Blocking += "-label:License-Blocks-Install+";
			Blocking += "-label:Network-Blocker+";
			Blocking += "-label:portable-archive+";
			Blocking += "-label:Project-File+";
			Blocking += "-label:Reboot+";
			Blocking += "-label:Scripted-Application+";
			Blocking += "-label:WindowsFeatures+";
			Blocking += "-label:zip-binary+";
			
			string Common = string_nBI;
			Common += "-"+string_IEM;
			Common += "-"+Defender;
			
			string Cna = string_VC;
			Cna += nApproved;
			
			string Review1 = "-label:Changes-Requested+";
			Review1 += "-label:Needs-CLA+";
			Review1 += "-label:No-Recent-Activity+";
			
			string Review2 = "-"+string_NA;
			Review2 += "-"+string_NAF;
			Review2 += "-label:Needs-Review+";
			
			string Workable = "-label:Validation-Merge-Conflict+";
			Workable += "-label:Unexpected-File+";
			
			//Composite settings;
			string Set1 = Common + Review1;
			string Set2 = Set1 + Review2;
			Url += Base;
			
			// if (Author != "") {
				// Url += "author:"+Author;
			// }
			// if (Commenter != "") {
				// Url += "commenter:"+Commenter;
			// }
			// if (Days > 0) {
				// Url += Recent;
			// }
			// if (IEDS == true) {
				// Url += nIEDS;
			// }
			// if (Label != "") {
				// Url += "label:"+Label;
			// }
			// if (NotWorked == true) {
				// Url += HaventWorked;
			// }
			// if (Title != "") {
				// Url += "Title in:title";
			// }
			if (Preset == "Approval") {
				Url += Cna;
				Url += Set2; //Blocking + Common + Review1 + Review2;
				Url += Workable;
			} else if (Preset == "Defender") {
				Url += Defender;
			} else if (Preset == "IEDS") {
				Url += IEDSLabel;
				Url += string_nBI;
				Url += Blocking;
				Url += NotPass;
				Url += string_nVC;
			} else if (Preset == "ToWork") {
				Url += Set1; //Blocking + Common + Review1;
				Url += "-"+Defender;
			} else if (Preset == "ToWork2") {
				Url += HaventWorked;
				Url += "-"+Defender;
				Url += Set1; //Blocking + Common + Review1;
				Url += string_nVC;
			}

			if (Browser == true) {
				System.Diagnostics.Process.Start(Url);
				return "";
				//System.Diagnostics.Process.Start("https://bing.com");
			} else {

			//if (NoLabels == true) {
				//return FromJson(InvokeGitHubRequest(Url))["items"].Where(n => n["labels"] != null);
			//} else {
				return FromJson(InvokeGitHubRequest(Url))["items"];
			}
			//}
		}


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
			} else if (Message == "InstallsNormally"){
				string_out = greeting + "This package installs and launches normally on a Windows 10 VM.";
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


		public string AutoValLog (int PR){
			//int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			//Download
			//Unzip
			//Filter
			//Post
			string string_out = "";
			int DownloadSeconds = 4;
			//Get-Process *photosapp* | Stop-Process
			int? BuildNumber = ADOBuildFromPR(PR);
			if (BuildNumber != null) {

				string Url =ADOMSBaseUrl+"/ed6a5dfa-6e7f-413b-842c-8305dd9e89e6/_apis/build/builds/" + BuildNumber + "/artifacts?artifactName=InstallationVerificationLogs&api-version=7.0&%24format=zip";
				System.Diagnostics.Process.Start(Url);//This downloads to Windows default location, which has already been set to DestinationPath
				Thread.Sleep(DownloadSeconds);//Sleep while download completes.

				RemoveItem(LogPath);
				using (FileStream compressedFileStream = File.Open(ZipPath, FileMode.Open)){
					using (FileStream outputFileStream = File.Create(DestinationPath)){
						using (var decompressor = new DeflateStream(compressedFileStream, CompressionMode.Decompress)){
							decompressor.CopyTo(outputFileStream);
						}
					}
				}
				RemoveItem(ZipPath);
				List<string> UserInput = new List<string>();

				string[] files = Directory.GetFileSystemEntries(LogPath, "*", SearchOption.AllDirectories);
				foreach (string file in files) {
						if (file.Contains("png")) {
							System.Diagnostics.Process.Start(file);
						} //Open PNGs with default app.
							string[] fileContents = GetContent(file).Split('\n');
							UserInput.Concat(fileContents.Where(n => n.Contains("[[]FAIL[]]")).ToList());
							UserInput.Concat(fileContents.Where(n => n.Contains("error")).ToList());
							UserInput.Concat(fileContents.Where(n => n.Contains("exception")).ToList());
							UserInput.Concat(fileContents.Where(n => n.Contains("exit code")).ToList());
							UserInput.Concat(fileContents.Where(n => n.Contains("fail")).ToList());
							UserInput.Concat(fileContents.Where(n => n.Contains("No suitable")).ToList());
							UserInput.Concat(fileContents.Where(n => n.Contains("not supported")).ToList());//not supported by this processor type
							// UserInput += fileContents.Where(n => n.Contains("not applicable")).ToList());
							UserInput.Concat(fileContents.Where(n => n.Contains("Unable to locate nested installer")).ToList());
							UserInput.Concat(fileContents.Where(n => n.Contains("Windows cannot install package")).ToList());
					}

				if (UserInput != null) {
					// if (UserInput.Contains("[FAIL] Installer failed security check.") || UserInput.Contains("Operation did not complete successfully because the file contains a virus or potentially unwanted software")) {
						//Get-GitHubPreset -Preset DefenderFail -PR PR
					// }

					UserInput = UserInput.Where(n => !n.Contains(" success or error status: 0")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("Windows Error Reporting")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("--- End of inner exception stack trace ---")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("api-ms-win-core-errorhandling")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("because the current user does not have that package installed")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("Could not create system restore point")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("Dest filename")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("ERROR: Signature Update failed")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("Exception during executable launch operation System.InvalidOperationException: No process is associated with this object.")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("Exception(1) ")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("Exit code: 0")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("Installation failed with exit code -1978334972")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("ISWEBVIEW2INSTALLED")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("ResultException")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("SchedNetFx")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("Setting error JSON 1.0 fields")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("Standard error: ")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("Terminating context")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("The FileSystemWatcher has detected an error ")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("The process cannot access the file because it is being used by another process")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("ThrowifExceptional")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("Windows Installer installed the product")).ToList();
					UserInput = UserInput.Where(n => !n.Contains("with working directory \"D:TOOLS\".")).ToList();
					UserInput = UserInput.Distinct().ToList();

					string message = "Automatic Validation ended with:" + Environment.NewLine + string.Join(Environment.NewLine+"> ",UserInput) +Environment.NewLine +Environment.NewLine + "(Automated response - build "+build+".)";

					string_out = ReplyToPR(PR,message);
				} else {
					string message = "Automatic Validation ended with:" + Environment.NewLine+"> No errors to post."+Environment.NewLine + Environment.NewLine +"(Automated response - build "+build+".)";
					string_out = ReplyToPR(PR,message);
				}
			} else {
				string message = "Automatic Validation ended with:" + Environment.NewLine+"> ADO Build not found."+Environment.NewLine + Environment.NewLine +"(Automated response - build "+build+".)";
				string_out = ReplyToPR(PR,message);
			}
			return string_out;
		}

//RandomIEDS

		public string RetryPR(int PR) {
			AddPRToRecord(PR,"Retry");
			return InvokeGitHubPRRequest(PR ,"POST","comments","@wingetbot run");
		}




		//PR tools
		//Add user to PR: InvokeGitHubPRRequest -Method $Method -Type "assignees" -Data $User -Output StatusDescription
		//Approve PR (needs work): InvokeGitHubPRRequest -PR $PR -Method Post -Type reviews
		public string InvokeGitHubPRRequest (int PR, string Method = WebRequestMethods.Http.Get,string Type = "labels",string Data = "",string Path = "issues") {
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
			if (Method == WebRequestMethods.Http.Get) {
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
			
			string out_var = InvokeGitHubRequest(Url,WebRequestMethods.Http.Post,Body);
			return out_var;
		}

		public string AddGitHubReviewComment (int PR, string Comment,int? StartLine,int Line) {
			dynamic Commit = FromJson(InvokeGitHubPRRequest(PR, WebRequestMethods.Http.Get, "commits","",""));
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
			dynamic content = FromJson(InvokeWebRequest(ADOMSBaseUrl+"/"+repo+"/_apis/build/builds?branchName=refs/pull/"+PR+"/merge&api-version=6.0"));
			string href = content["value"][0]["_links"]["web"]["href"];
			int PRbuild = Int32.Parse(href.Split('=')[1]);
			return PRbuild;
		}

		public string LineFromCommitFile(int PR, int LogNumber, string SearchString = "Specified hash doesn't match", int NumberOfLines = 0){
			int PRbuild = ADOBuildFromPR(PR);
			// Take the returned string,
			string Content = InvokeWebRequest(ADOMSBaseUrl+"/ed6a5dfa-6e7f-413b-842c-8305dd9e89e6/_apis/build/builds/"+PRbuild+"/logs/"+LogNumber);
		// slice by line breaks,
			string[] SplitContent = Content.Split('\n'); 
			
			string output = "";
			int StartLine = 0;
			int EndLine = 0;
			for (int i = 0; i < SplitContent.Length; i++) {
		// find the string containing the SearchString,
				if (SplitContent[i].Contains(SearchString)) {
					StartLine = i;
					EndLine = StartLine + NumberOfLines;
				}
		// gather it and the next Length lines,
				if (StartLine <= i && i <= EndLine) {
		// Join these into a single string by line breaks 
					output += SplitContent[i] + Environment.NewLine;
				}
			}
		//and return.
			return output;
		}

		public void GetPRApproval(string Clip = ""){
			if (Clip == "") {
				Clip = Clipboard.GetText();
			}
			//Happens only during Bulk Approval, when manifest is in clipboard.
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string PackageIdentifier = ((Clip.Split(':'))[1].Split(' ')[0]);
			string auth = GetValidationData("PackageIdentifier",PackageIdentifier,true)["GitHubUserName"];
			List<string> Approver = auth.Split('/').Where(n => !n.Contains("(")).ToList();
			string string_joined = string.Join("; @", Approver);
			ReplyToPR(PR,string_joined,"Approve","Needs-Review");
		}

		public string ReplyToPR (int PR,string string_CannedMessage, string string_UserInput = "", string Policy = "", string Body = ""){
/*
			Dictionary<string,object> PRContent = new Dictionary<string,object>();
			PRContent = FromJson(InvokeGitHubPRRequest(PR,"","content"));
			string from_mid = ToJson(PRContent["user"]);
			Dictionary<string,object> to_user = new Dictionary<string,object>();
			to_user = FromJson(from_mid);
			string string_UserInput = to_user["login"].ToString();
*/
			if (Body == "") {
				Body = CannedMessage(string_CannedMessage,string_UserInput);
			}
			if (Policy != "") {
				Body += "\n<!--\n[Policy] "+Policy+"\n-->";
			}
			return InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments",Body,"issues");
		}

		public bool CheckStandardPRComments (int PR,Dictionary<string,object> comments = null) {
			bool out_bool = false;
			if (comments == null) {
				comments = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Get,"comments","",""));
			}
			foreach (string StdComment in StandardPRComments) {
				if (!comments.Keys.Any(key => key.Contains(StdComment))) {
					out_bool = true;
				}
			}
			return out_bool;
		}

		public List<string> PRStateFromComments (int PR){
			Dictionary<string,object>[] Comments = FromJson(InvokeGitHubPRRequest(PR,"comments","","","content")); //| select created_at,@{n="UserName";e={$_.user.login -replace "\[bot\]"}},body)
			//Robot usernames
			string Wingetbot = "wingetbot";
			string AzurePipelines = "azure-pipelines";
			string FabricBot = "microsoft-github-policy-service";
			List<string> OverallState = new List<string>();
			
			foreach (Dictionary<string,object> Comment in Comments) {
				string State = "";
				string UserName = (string)Comment["UserName"];
				string body = (string)Comment["body"];
				//DateTime created_at = TimeZoneInfo.ConvertTimeBySystemTimeZoneId((DateTime)Comment["created_at"], "Pacific Standard Time");

				if (string.Equals(UserName, Wingetbot) && body.Contains("Service Badge")) {
					State = "PreRun";
				}
				if (body.Contains("AzurePipelines run") || 
				body.Contains("AzurePipelines run") || 
				body.Contains("azp run") || 
				body.Contains("wingetbot run")) {
					State = "PreValidation";
				}
				if (string.Equals(UserName, AzurePipelines) && body.Contains("Azure Pipelines successfully started running 1 pipeline")) {
					State = "Running";
				}
				if (string.Equals(UserName, FabricBot) && body.Contains("The check-in policies require a moderator to approve PRs from the community")) {
					State = "PreApproval";
				}
				if (string.Equals(UserName, GitHubUserName) && body.Contains("The package didn't pass a Defender or similar security scan")) {
					State = "DefenderFail";
				}
				if (string.Equals(UserName, GitHubUserName) && body.Contains("Status Code: 200")) {
					State = "InstallerAvailable";
				}
				if (string.Equals(UserName, GitHubUserName) && body.Contains("Response status code does not indicate success")) {
					State = "InstallerRemoved";
				}
				if (string.Equals(UserName, GitHubUserName) && body.Contains("which is greater than the current manifest's version")) {
					State = "VersionParamMismatch";
				}
				if (string.Equals(UserName, FabricBot) && (
				string.Equals(body, "The package manager bot determined there was an issue with one of the installers listed in the url field") || //URL error
				string.Equals(body, "The package manager bot determined there was an issue with installing the application correctly") || //Validation-Installation-Error
				string.Equals(body, "The pull request encountered an internal error and has been assigned to a developer to investigate") ||  //Internal-Error
				string.Equals(body, "this application failed to install without user input")  || //Validation-Unattended-Failed
				string.Equals(body, "Please verify the manifest file is compliant with the package manager") //Manifest-Validation-Error
				)) {
					State = "LabelAction";
				}
				if (string.Equals(UserName, FabricBot) && body.Contains("One or more of the installer URLs doesn't appear valid")) {
					State = "DomainReview";
				}
				if (string.Equals(UserName, GitHubUserName) && body.Contains("Sequence contains no elements")) {
					State = "SequenceError";
				}
				if (string.Equals(UserName, GitHubUserName) && body.Contains("This manifest has the highest version number for this package")) {
					State = "HighestVersionRemoval";
				}
				if (string.Equals(UserName, GitHubUserName) && body.Contains("SQL error or missing database")) {
					State = "SQLMissingError";
				}
				if (string.Equals(UserName, FabricBot) && body.Contains("The package manager bot determined changes have been requested to your PR")) {
					State = "ChangesRequested";
				}
				if (string.Equals(UserName, FabricBot) && body.Contains("I am sorry to report that the Sha256 Hash does not match the installer")) {
					State = "HashMismatch";
				}
				if (string.Equals(UserName, GitHubUserName) && body.Contains("Automatic Validation ended with:")) {
					State = "AutoValEnd";
				}
				if (string.Equals(UserName, GitHubUserName) && body.Contains("Manual Validation ended with:")) {
					State = "ManValEnd";
				}
				if (string.Equals(UserName, AzurePipelines) && body.Contains("Pull request contains merge conflicts")) {
					State = "MergeConflicts";
				}
				if (string.Equals(UserName, FabricBot) && body.Contains("Validation has completed")) {
					State = "ValidationCompleted";
				}
				if (string.Equals(UserName, Wingetbot) && body.Contains("Publish pipeline succeeded for this Pull Request")) {
					State = "PublishSucceeded";
				}
				if (!string.Equals(State, "")) {
					OverallState.Add(State); //| select @{n="event";e={State}},created_at;
				}
			}
			return OverallState;
		}





		//Network tools
		//GET = Read; POST = Append; PUT = Write; DELETE = delete
		public string InvokeGitHubRequest(string Url,string Method = WebRequestMethods.Http.Get,string Body = "",bool JSON = false){
					string response_out = "";
					//This wrapper function is a relic of the PowerShell version, and should be obviated during a refactor. The need it meets in the PowerShell version - inject authentication headers into web requests, is met here directly inside the InvokeWebRequest function below. But having it here during the port process (code portage) reduces the amount of work needed to port the other functions were written to use it.

			if (Body == "") {
				try {
					response_out = InvokeWebRequest(Url, Method,"",true);//  Headers Body -ContentType "application/json";
				} catch (Exception e) {
					//MessageBox.Show("Wrong request!" + ex.Message, "Error");
					response_out = e.Message;
				}
			} else {
				try {
					response_out = InvokeWebRequest(Url, Method, Body,true);//  Headers -ContentType "application/json";
				} catch (Exception e) {
					//MessageBox.Show("Wrong request!" + ex.Message, "Error");
					response_out = e.Message;
				}
			}

			if (JSON == true) {
			}

			return response_out;
		}
		//GitHub requires the value be the .body property of the variable. This makes more sense with CURL, Where-Object this is the -data parameter. However with InvokeWebRequest it's the -Body parameter, so we end up with the awkward situation of having a Body parameter that needs to be prepended with a body property.

		public string PRInstallerStatusInnerWrapper (string Url){
			//This was a hack to get around Invoke-WebRequest hard blocking on failure, where this needed to be captured and transmitted to a PR comment. And so might not be needed here.
			return InvokeWebRequest(Url, "Head");//.StatusCode;
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
				} else{
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

		public void LaunchWindow(int VM, string VMName = ""){
			if (VMName == "") {
				VMName = "vm"+VM;
			}
			TestAdmin();
			var processes = Process.GetProcessesByName("vmconnect");
			foreach (Process process in processes){
				if (process.MainWindowTitle.Contains(VMName)) {
				process.CloseMainWindow();
				}
			}
			var newProcess = new System.Diagnostics.Process();
			newProcess.StartInfo.FileName = "C:\\Windows\\System32\\vmconnect.exe";
			newProcess.StartInfo.Arguments = "localhost" + VMName;
			newProcess.Start();
		}

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

		//GetStatus = FromCsv(GetContent(StatusFile));
		//WriteStatus = OutFile(StatusFile,string_out);

		public void ResetStatus() {
			IEnumerable<Dictionary<string,dynamic>> VMs = FromCsv(GetContent(StatusFile))
			.Where(n => n["Status"] != "Ready")
			.Where(n => (int)n["RAM"] == 0);
			
			foreach (Dictionary<string,dynamic> VM in VMs) {
				SetStatus(VM["VM"],"Complete");
			}
			VMs = FromCsv(GetContent(StatusFile)).Where(n => n["Status"] != "Ready").Where(n => (string)n["Package"] == "");
			foreach (Dictionary<string,dynamic> VM in VMs) {
				SetStatus(VM["VM"],"Complete");
			}
			var processes = Process.GetProcessesByName("vmconnect");
			if (processes.Length == 0){
				StopProcessesByName("vmwp");
			}
		}
			
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

			string Mode = "";
			if (TestPath(TrackerModeFile) == "File") {
				Mode = GetMode();
			}
			if (Mode == "Approving") {
				//#F0F0F0 or RGB 240, 240, 240
				btn10.BackColor = color_ActiveBack;//Bulk Approving
				btn18.BackColor = color_DefaultBack;//Individual Validations
				btn11.BackColor = color_DefaultBack;//IEDS
				btn19.BackColor = color_DefaultBack;//Idle
				btn20.BackColor = color_DefaultBack;//Config
			} else if (Mode == "Validating") {
				//#F0F0F0 or RGB 240, 240, 240
				btn10.BackColor = color_DefaultBack;//Bulk Approving
				btn18.BackColor = color_ActiveBack;//Individual Validations
				btn11.BackColor = color_DefaultBack;//IEDS
				btn19.BackColor = color_DefaultBack;//Idle
				btn20.BackColor = color_DefaultBack;//Config
			} else if (Mode == "IEDS") {
				//#F0F0F0 or RGB 240, 240, 240
				btn10.BackColor = color_DefaultBack;//Bulk Approving
				btn18.BackColor = color_DefaultBack;//Individual Validations
				btn11.BackColor = color_ActiveBack;//IEDS
				btn19.BackColor = color_DefaultBack;//Idle
				btn20.BackColor = color_DefaultBack;//Config
			} else if (Mode == "Idle") {
				//#F0F0F0 or RGB 240, 240, 240
				btn10.BackColor = color_DefaultBack;//Bulk Approving
				btn18.BackColor = color_DefaultBack;//Individual Validations
				btn11.BackColor = color_DefaultBack;//IEDS
				btn19.BackColor = color_ActiveBack;//Idle
				btn20.BackColor = color_DefaultBack;//Config
			} else if (Mode == "Config") {
				//#F0F0F0 or RGB 240, 240, 240
				btn10.BackColor = color_DefaultBack;//Bulk Approving
				btn18.BackColor = color_DefaultBack;//Individual Validations
				btn11.BackColor = color_DefaultBack;//IEDS
				btn19.BackColor = color_DefaultBack;//Idle
				btn20.BackColor = color_ActiveBack;//Config
			} 
			

			if (TestPath(StatusFile) == "File") {
				int VMRAM = 0;
				string string_ram = "";
				Dictionary<string,object>[] GetStatus = FromCsv(GetContent(StatusFile));
				for (int VM = 0; VM < GetStatus.Length; VM++) {
					try {
						string_ram += GetStatus[VM]["RAM"]+" ";
					} catch (Exception e) {
						inputBox_VMRAM.Text = e.ToString();
					}
				}
				string[] ram_split = string_ram.Split(' ');
				for (int VM = 0; VM < ram_split.Length; VM++) {
					try {
					VMRAM += Int32.Parse(ram_split[VM]);
					} catch (Exception e) {
						inputBox_VMRAM.Text = e.ToString();
					}
				}
				inputBox_VMRAM.Text = string_ram.ToString();
			}
			
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

		public void RotateVMs(string OS = "Win10") {
		Random rnd = new Random(); 
		Dictionary<string,object>[] GetStatus = FromCsv(GetContent(StatusFile));
		var VMs = GetStatus.Where(n => (int)n["version"] < GetVMVersion(OS))
		.Where(n => n["OS"] == OS)
		.Where(n => n["status"] != "Ready");
			if (VMs != null){
				int counter = 0;
				int rand_VM = rnd.Next(VMs.Count());
				foreach (Dictionary<string,object> FullVM in VMs) {
					counter++;
					if (rand_VM == counter) {
						SetStatus((int)FullVM["vm"],"Regenerate"); 
					}
				}//end foreach FullVM
			}//end if VMs
		}//end function
		







//VM Orchestration
//VMCycle
		public string GetMode() {
			return GetContent(TrackerModeFile);
		}

		public void SetMode(string Status = "Validating") {
			//[ValidateSet("Approving","Idle","IEDS","Validating")]
			OutFile(TrackerModeFile,Status);
		}

		//ConnectedVM = var processes = Process.GetProcessesByName("vmconnect");

		public int NextFreeVM(string OS = "Win10",string Status = "Ready") {
	//[ValidateSet("Win10","Win11")]
		int int_out = 0;
		Random rnd = new Random(); 
		Dictionary<string,object>[] GetStatus = FromCsv(GetContent(StatusFile));
		var VMs = GetStatus.Where(n => (int)n["version"] < GetVMVersion(OS))
		.Where(n => n["OS"] == OS)
		.Where(n => n["status"] == Status);
			if (VMs != null){
				int counter = 0;
				int rand_VM = rnd.Next(VMs.Count());
				foreach (Dictionary<string,object> FullVM in VMs) {
					counter++;
					if (rand_VM == counter) {
						int_out = (int)FullVM["vm"]; 
					}
				}//end foreach FullVM
			}//end if VMs
		
		return int_out;
		//Write-Host "No available $OS VMs"
		}//end function

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
			for (int depthUnit = depth;depthUnit > 0; depthUnit--){
				sa_out.Add(clipArray[-depthUnit]);
				
			}
		string string_joined = string.Join("\n", sa_out);
		return string_joined;
		}



		//RemoveFileifExist(FileName) = RemoveItem(FIleName);
		//LoadFileIfExists(FileName) = GetContent(FIleName);

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
		public void AddToValidationFile(int VM, string Dependency){
				string VMFolder = MainFolder+"\\vm\\"+VM;
				string manifestFolder = VMFolder+"\\manifest";
				string FilePath = "manifestFolder\\Package.installer.yaml";
				string fileContents = GetContent(FilePath);
				//string Selector = "Installers:";
				// int offset = 1;
				// int lineNo = 0;//((fileContents| Select-String Selector -List).LineNumber -offset);
				//string fileInsert = "Dependencies:\n  PackageDependencies:\n     - PackageIdentifier: Dependency";
				string fileOutput = fileContents;//(fileContents[0..(lineNo -1)]+fileInsert+fileContents[lineNo..(fileContents.Length)]);
				OutFile(FilePath,fileOutput);
				SetStatus(VM,"Revert");
		}

		public void AddInstallerSwitch(int VM, string Data){
				string VMFolder = MainFolder+"\\vm\\"+VM;
				string manifestFolder = VMFolder+"\\manifest";
				string FilePath = "manifestFolder\\Package.installer.yaml";
				string fileContents = GetContent(FilePath);
				// string Selector = "ManifestType:";
				// int offset = 1;
				// int lineNo = 0;//((fileContents| Select-String Selector -List).LineNumber -offset);
				// string fileInsert = "  InstallerSwitches:\n    Silent: $Data";
				string fileOutput = fileContents;//(fileContents[0..(lineNo -1)]+fileInsert+fileContents[lineNo..(fileContents.Length)]);
				OutFile(FilePath,fileOutput);
				SetStatus(VM,"Revert");
		}






//Inject into PRs
/*
public string AddDependencyToPR(int PR){
	string Dependency = "Microsoft.VCRedist.2015+.x64",
	string SearchString = "Installers:",
	string LineNumbers = CommitFile(PR, string File, string url)   (Select-String SearchString).LineNumber),
	string ReplaceString = "Dependencies:\n  PackageDependencies:\n   - PackageIdentifier: $Dependency\nInstallers:",
	string comment = "\\\\\\suggestion\n$ReplaceString\n\\\\\\\n\n(Automated response - build $build.)"
	string_out = ""
	foreach ($Line in $LineNumbers) {
		string_out += Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Policy "Needs-Author-Feedback"
	}
}
public string UpdateHashInPR(int PR, string ManifestHash, string PackageHash, string LineNumbers = ((Get-CommitFile -PR $PR | Select-String ManifestHash).LineNumber), string ReplaceTerm = ("  InstallerSha256: $($PackageHash.toUpper())"), string comment = "\\\\\\suggestion\n$ReplaceString\n\\\\\\\n\n(Automated response - build $build.)"){
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Policy "Needs-Author-Feedback"
	}
}

public string UpdateHashInPR2(int PR, string clip, string SearchTerm = "Expected hash", string ManifestHash = (YamlValue $SearchTerm -Clip $Clip), string LineNumbers = ((Get-CommitFile -PR $PR | Select-String ManifestHash).LineNumber), string ReplaceTerm = "Actual hash", string PackageHash = ("  InstallerSha256: "+(YamlValue $ReplaceTerm -Clip $Clip).toUpper()), string comment = "\\\\\\suggestion\n$ReplaceString\n\\\\\\\n\n(Automated response - build $build.)"){
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Policy "Needs-Author-Feedback"
	}
}

public string UpdateArchInPR(int PR, string SearchTerm = "  Architecture: x86", string LineNumbers = ((Get-CommitFile -PR $PR | Select-String SearchTerm).LineNumber),string ReplaceTerm = (($SearchTerm.Split(": "))[1]),string ReplaceArch = (("x86","x64").Where(n => n -notmatch $ReplaceTerm}), string ReplaceString = ($SearchTerm.Replace($ReplaceTerm, string ReplaceArch), string comment = "\\\\\\suggestion\n$ReplaceString\n\\\\\\\n\n(Automated response - build $build.)")){
[ValidateSet("x86","x64","arm","arm32","arm64","neutral")]
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Policy "Needs-Author-Feedback"
	}
}
*/






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

		public dynamic PRFromRecord(string string_action){
		//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			PRPopulateRecord();
			return FromCsv(GetContent(LogFile)).Where(n => n["Action"].Contains(string_action));
		}

		public string PRReportFromRecord(string string_action, string string_out = "", int line = 0) {
			//Add items to dictionary array then remove from file.
			Dictionary<string,dynamic>[] Records = PRFromRecord(string_action);
			dynamic dynamic_csv = FromCsv(GetContent(LogFile)).Where(n => !n["Action"].Contains(string_action)).ToList();
			string string_csv = ToCsv(dynamic_csv);
			OutFile(LogFile,string_csv);
			
			foreach (Dictionary<string,dynamic> Record in Records) {
				line++;
				string Title = Record["Title"];
				int PR = Record["PR"];
				if (Title == null) {
					Title = FromJson(InvokeGitHubPRRequest(PR,"","content"))["title"];
				}
				TrackerProgress(PR,System.Reflection.MethodBase.GetCurrentMethod().Name,line,Records.Length);
				string_out += Title+" #"+PR+Environment.NewLine;
			}
			return string_out;
		}

		public void PRFullReport() {
			string ReportName = logsFolder+"\\"+DateTime.Now.ToString("MMddyy")+"-Report.txt";
			string[] PRTypes = {"Feedback","Blocking","Waiver","Retry","Manual","Closed","Project","Squash","Approved"};
			foreach (string Type in PRTypes) {
				string string_out = Type+Environment.NewLine+Environment.NewLine+Environment.NewLine+PRReportFromRecord(Type);
				OutFile(ReportName,string_out,true);
			}
		}






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

		public string SortedClipboard(string string_in){
			IEnumerable<string> string_array = string_in.Split('\n').Distinct();
			string string_joined = string.Join("\n", string_array);
			return string_joined;
		}

		public void OpenAllURLs (string Clip = ""){
			if (Clip == "") {
				Clip = Clipboard.GetText();
			}
			IEnumerable<string> Urls;
			Urls = Clip.Split(' ');
			Urls = Urls.Where(n => n.Contains("http"));
			Urls = Urls.Where(n => !n.Contains("[.]exe$"));
			Urls = Urls.Where(n => !n.Contains("[.]msi$"));
			Urls = Urls.Where(n => !n.Contains("[.]zip$"));
			Urls = Urls.Distinct();
			foreach (string Url in Urls) {
				System.Diagnostics.Process.Start(Url);
			}
		}

		public void OpenPRInBrowser(int PR,bool Files = false){
			string URL = GitHubBaseUrl+"/pull/"+PR+"#issue-comment-box";
			if (Files == true) {
				URL = GitHubBaseUrl+"/pull/"+PR+"/files";
			}
			System.Diagnostics.Process.Start(URL);
		}//end Function

		public string YamlValue(string ContainsString, string YamlString){
			//Split YamlString by \n
			//String where equals StringName
			YamlString = YamlString.Split(' ').Where(n => n.Contains(ContainsString)).FirstOrDefault(); // s.IndexOf(": ");
			YamlString = YamlString.Split(':')[1];
			YamlString = YamlString.Split('#')[0];
			//YamlString = (YamlString.ToCharArray().Where(n => n.Contains("\\S"}).Join("");
			return YamlString;
		}






//Etc
		public bool TestAdmin() {
			bool isAdmin = new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);
			if (isAdmin == true) {
				MessageBox.Show("Try elevating your session." + Environment.NewLine, "Error");
			}
			return isAdmin;
		}

		public void TrackerProgress(int PR, string Activity, int Incrementor, int Length){
			//double Percent = System.Math.Round(Incrementor / Length*100,2);
			//Write-Progress -Activity $Activity -Status "$PR - $Incrementor / $Length = $Percent %" -PercentComplete Percent
		}

		public double ArraySum(int[] int_in){
			int sum = int_in.Sum();
			return sum;//Math.Round(sum,2);
		}

		public void GitHubRateLimit(){
			//Time, as a number, constantly increases. 
			string Url = "https://api.github.com/rate_limit";
			dynamic Unlogged_Rate = FromJson(InvokeWebRequest(Url));
			//Unlogged_Rate["rate"] | select @{n="source";e={"Unlogged"}}, limit, used, remaining, @{n="reset";e={([System.DateTimeOffset]::FromUnixTimeSeconds(_.reset)).DateTime.AddHours(-8)}}
			
			dynamic Logged_Rate = FromJson(InvokeGitHubRequest(Url));
			//Response["rate"] | select @{n="source";e={"Logged"}}, limit, used, remaining, @{n="reset";e={([System.DateTimeOffset]::FromUnixTimeSeconds(_.reset)).DateTime.AddHours(-8)}}
		}

		public dynamic GetValidationData(string Property, string Match = "",bool Exact = false){
			if (Exact == true) {
				return FromCsv(GetContent(DataFileName)).Where(n => n[Property] != null).Where(n => (string)n[Property] == Match);
			} else if (Match != ""){
				return FromCsv(GetContent(DataFileName)).Where(n => n[Property] != null).Where(n => Match.Contains((string)n[Property]));
			} else {
				return FromCsv(GetContent(DataFileName)).Where(n => n[Property] != null);
			}
		}


public void AddValidationData(string PackageIdentifier,string GitHubUserName = "",string authStrictness = "",string authUpdateType = "",string autoWaiverLabel = "",string versionParamOverrideUserName = "",int versionParamOverridePR = 0,string code200OverrideUserName = "",int code200OverridePR = 0,int AgreementOverridePR = 0 ,string AgreementURL = "",string reviewText = ""){
//[ValidateSet("should","must")]
//[ValidateSet("auto","manual")]
	
	//Find the line with the PackageIdentifier, then if it's null, make a new line and insert.
			dynamic data = FromCsv(GetContent(DataFileName));
			for (int r = 1; r < data.Length -1; r++){
				var row = data[r];
				
				if (row["PackageIdentifier"] == PackageIdentifier) {
					row["GitHubUserName"] = GitHubUserName;
					row["authStrictness"] = authStrictness;
					row["authUpdateType"] = authUpdateType;
					row["autoWaiverLabel"] = autoWaiverLabel;
					row["versionParamOverrideUserName"] = versionParamOverrideUserName;
					row["versionParamOverridePR"] = versionParamOverridePR;
					row["code200OverrideUserName"] = code200OverrideUserName;
					row["code200OverridePR"] = code200OverridePR;
					row["AgreementURL"] = AgreementURL;
					row["AgreementOverridePR"] = AgreementOverridePR;
					row["reviewText"] = reviewText;
				}//end if row vm
			}//end for r

/*
	if (null == string_out) {0
		string_out = ( "" | Select-Object "PackageIdentifier","GitHubUserName","authStrictness","authUpdateType","autoWaiverLabel","versionParamOverrideUserName","versionParamOverridePR","code200OverrideUserName","code200OverridePR","AgreementOverridePR","AgreementURL","reviewText")
		string_out.PackageIdentifier = PackageIdentifier
	}

		data += string_out
		data = data.OrderBy(o=>o["PackageIdentifier"]).ToArray();
*/
		OutFile(DataFileName, ToCsv(data));
}






//PR Watcher Utility functions
		public void Sandbox(string string_PRNumber){
			int int_PRNumber = 0;
			if (string_PRNumber[0] == '#') {
				int_PRNumber = Int32.Parse(string_PRNumber.Substring(1,string_PRNumber.Length));
			}
			StopProcessesByName("sandbox");
			StopProcessesByName("wingetautomator");
			string version = "1.6.1573-preview";//This is out of date.
			string process ="wingetautomator://install?pull_request_number="+int_PRNumber.ToString()+"&winget_cli_version=v"+version.ToString()+"&watch=yes";
			System.Diagnostics.Process.Start(process);
		}

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

		public void StopProcessesByName(string ProcessName) {
			var processes = Process.GetProcessesByName(ProcessName);
			foreach (Process process in processes){
				process.CloseMainWindow();
				//Stop-Process Process.CloseMainWindow(); or Process.Kill();
			} 
		}






		//Powershell functional equivalency imperatives
		//Get-Clipboard = Clipboard.GetText();
		//Get-Date = DateTime.Now.ToString("M/d/yyyy");
		//Get-Process = public Process[] processes = Process.GetProcesses(); or var processes = Process.GetProcessesByName("Test");
		//New-Item = Directory.CreateDirectory(Path) or File.Create(Path);
		//Remove-Item = Directory.Delete(Path) or File.Delete(Path);
		//Get-ChildItem = string[] entries = Directory.GetFileSystemEntries(path, "*", SearchOption.AllDirectories);
		//Start-Process = System.Diagnostics.Process.Start(PathOrUrl);
		//Stop-Process Process.CloseMainWindow(); or Process.Kill();
		//Start-Sleep = Thread.Sleep(GitHubRateLimitDelay);
		//Get-Random - Random rnd = new Random(); or int month  = rnd.Next(1, 13);  or int card   = rnd.Next(52);
		//Create-Archive = ZipFile.CreateFromDirectory(dataPath, zipPath);
		//Expand-Archive = ZipFile.ExtractToDirectory(zipPath, extractPath);
		//Sort-Object = .OrderBy(n=>n).ToArray(); and -Unique = .Distinct(); Or Array.Sort(strArray); or List

		//JSON
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
			if (TestPath(path) == "None") {
				File.Create(path);
			}
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
		public string InvokeWebRequest(string Url, string Method = WebRequestMethods.Http.Get, string Body = "",bool Authorization = false){ 
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
		}// end InvokeWebRequest	

		public void RemoveItem(string Path,bool remake = false){
			if (TestPath(Path) != "File") {
				File.Delete(Path);
				if (remake) {
					File.Create(Path);
				}
			} else if (TestPath(Path) != "Directory") {
				Directory.Delete(Path, true);
				if (remake) {
					Directory.CreateDirectory(Path);
				}
			}
		}




		//VM Window Management
		[DllImport("user32.dll")]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

		[DllImport("user32.dll")]
		public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

		public struct RECT {
			public int Left; // x position of upper-left corner
			public int Top; // y position of upper-left corner
			public int Right; // x position of lower-right corner
			public int Bottom; // y position of lower-right corner
		}

		public RECT rect;

		public void  TrackerVMWindowLoc (int VM,ref RECT rect,IntPtr MWHandle) {
			//Need to readd the logic that finds the mainwindowhandle from the VM number.
			GetWindowRect(MWHandle,out rect);
		}

		public void  TrackerVMWindowSet (int VM,int Left,int Top,int Right,int Bottom,IntPtr MWHandle) {
			MoveWindow(MWHandle,Left,Top,Right,Bottom,true);
		}

		public void  TrackerVMWindowArrange() {
			Dictionary<string,object>[] GetStatus = FromCsv(GetContent(StatusFile));

			var VMs = GetStatus.Where(n => (string)n["status"] != "Ready").Select(n => n["vm"]);

			if (VMs != null) {
/*
				RECT Base;
				TrackerVMWindowSet(VMs[0],900,0,1029,860)
				TrackerVMWindowLoc(VMs[0], ref Base)
				
				for (int n = 1;n < VMs.count;n++) {
					Dictionary<string,object> VM = VMs[n]
					
					int Left = (Base.left - (100 * n))
					int Top = (Base.top + (66 * n))
					TrackerVMWindowSet(VM,Left,Top,1029,860)
				}
*/
			}

/*
				for (int VM = 0; VM < GetStatus.Length; VM++) {
					try {
						string_ram += GetStatus[VM]["RAM"]+" ";
					} catch (Exception e) {
						inputBox_VMRAM.Text = e.ToString();
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
			//InvokeWebRequest(ref pageSource, imageUrl, WebRequestMethods.Http.Get);

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
			SearchGitHub("ToWork",1,0, false,false,true);
        }// end Approved_Button_Click
		
        public void Squash_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Squash");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + "Squash");
        }// end Approved_Button_Click
		
        public void Add_Waiver_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string string_out = AddWaiver(PR);
			outBox_val.AppendText(Environment.NewLine + "Waiver: "+PR + " "+ string_out);
			//outBox_val.AppendText(Environment.NewLine + CannedMessage("AutoValEnd","testing testing 1..2..3."));
        }// end Approved_Button_Click
		
        public void Open_In_Browser_Button_Click(object sender, EventArgs e) {
			SearchGitHub("Approval",1,0, false,false,true);
        }// end Approved_Button_Click
		
        public void Retry_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string response_out = InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","@wingetbot run","Silent");
			AddPRToRecord(PR,"Retry");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
			}// end Approved_Button_Click

        public void Approved_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string response_out = ApprovePR(PR);
			AddPRToRecord(PR,"Approved");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Approved_Button_Click
		
        public void Driver_Install_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string response_out = ReplyToPR(PR,"DriverInstall","DriverInstall");
			AddPRToRecord(PR,"Blocking");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Driver_Install_Button_Click
		
        public void Manually_Validated_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string response_out = ReplyToPR(PR,"InstallsNormally","Manually-Validated");
			AddPRToRecord(PR,"Manual");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Manually_Validated_Button_Click
		
        public void Project_File_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Project");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + "Project");
        }// end Project_File_Button_Click
		
        public void Closed_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string UserInput = inputBox_User.Text;
			AddPRToRecord(PR,"Closed");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string response_out = InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: "+UserInput+";");
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Closed_Button_Click
		
        public void Duplicate_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			int UserInput = Int32.Parse(inputBox_User.Text.Replace("#",""));
			AddPRToRecord(PR,"Closed");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string response_out = InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: Duplicate of #"+UserInput+";");
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Duplicate_Button_Click
		
        public void Automation_Block_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Blocking");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string response_out = ReplyToPR(PR,"AutomationBlock","Network-Blocker");
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
		}// end Automation_Block_Button_Click

        public void Installer_Not_Silent_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Feedback");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string response_out = ReplyToPR(PR,"InstallerNotSilent",MagicLabels[30]);
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Installer_Not_Silent_Button_Click
		
        public void Installer_Missing_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Feedback");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string response_out = ReplyToPR(PR,"InstallerMissing",MagicLabels[30]);
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Installer_Missing_Button_Click
		
        public void Needs_PackageUrl_Button_Click(object sender, EventArgs e) {
			//outBox_val.AppendText(Environment.NewLine + SearchGitHub("Approval")[0]["number"]);
			Process[] processes = Process.GetProcesses(); 
			outBox_val.AppendText(Environment.NewLine + processes[0]);
        }// end Needs_PackageUrl_Button_Click
		
        public void Manifest_One_Per_PR_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Feedback");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string response_out = ReplyToPR(PR,"OneManifestPerPR",MagicLabels[30]);
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Manifest_One_Per_PR_Button_Click
		
        public void Merge_Conflicts_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Closed");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string response_out = InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: Merge Conflicts;");
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Merge_Conflicts_Button_Click
		
        public void Check_Installer_Button_Click(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			var Pull = FromJson(InvokeGitHubPRRequest(PR,"files"));
			string PullInstallerContents = DecodeGitHubFile(FromJson(InvokeGitHubRequest(Pull["contents_url"][0])));
			string Url = YamlValue("InstallerUrl",PullInstallerContents);
			string string_out = "";
			try {
				string InstallerStatus = PRInstallerStatusInnerWrapper(Url);
				string_out = "Status Code: "+InstallerStatus;
			}catch (Exception err){
				string_out = err.Message;
			}

			AddPRToRecord(PR,"Closed");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string Body = "URL: " + Url + Environment.NewLine + string_out + Environment.NewLine+Environment.NewLine+"(Automated message - build " + build + ")";
			string response_out = InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments",Body);
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);

				//if ($Body.Contains("Response status code does not indicate success") {	//string response_out = Get-GitHubPreset InstallerMissing -PR $PR 
				//} //Need this to only take action on new PRs, not removal PRs.
        }// end Check_Installer_Button_Click
		
		//Modes
        public void Approving_Button_Click(object sender, EventArgs e) {
			string Status = "Approving";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			//outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Approving_Button_Click
		
        public void IEDS_Button_Click(object sender, EventArgs e) {
			string Status = "IEDS";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			//outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end IEDS_Button_Click
		
        public void Validating_Button_Click(object sender, EventArgs e) {
			string Status = "Validating";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			//outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Validating_Button_Click
		
        public void Idle_Button_Click(object sender, EventArgs e) {
			string Status = "Idle";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			//outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Idle_Button_Click

        public void Config_Button_Click(object sender, EventArgs e) {
			string Status = "Idle";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			//outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Config_Button_Click



/*
			"CheckInstaller" {
			}
*/


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
"Sequence contains no elements",//New Sequence error.
"Missing Properties value based on version"//New property detection.
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



/* Miscellany 
		//SO: You can use the Distinct method to return an IEnumerable<T> of distinct items:
		//var uniqueItems = yourList.Distinct();
		//And if you need the sequence of unique items returned as a List<T>, you can add a call to ToList:
		//var uniqueItemsList = yourList.Distinct().ToList();

			string Path = "issues";
			string Type = "comments";
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string Url = GitHubApiBaseUrl+"/"+Path+"/"+PR+"/"+Type;
			string response_in = "";
			string response_out = "";
			string Body = "Test";//"@wingetbot waivers Add $Waiver"
			
			
			response_in = InvokeGitHubPRRequest(PR, WebRequestMethods.Http.Get,Type,Body);
			foreach (System.Collections.Generic.Dictionary<string,object> item in FromJson(response_in)) {
				string myText; 
				myText = System.String.Format("created_at={0}, id={1}",item["created_at"], item["id"]); 
				response_out += "- response_list " + myText;//serializer.Serialize(item);
			}

			outBox_val.AppendText(Environment.NewLine + WebRequestMethods.Http.Get + " " +  Url + " - " + response_out);

		if (TestPath(StatusFile) == "File") {
				dynamic Records = FromCsv(GetContent(StatusFile));
				//var Records = csv.GetRecords<class_VMVersion>();
				outBox_val.AppendText(Environment.NewLine + "Records.Length: "+Records.Length);
				for (int r = 1; r < Records.Length -1; r++){
						outBox_val.AppendText(Environment.NewLine + "OS: " + Records[r]["OS"] + " - Version: " + Records[r]["Version"]);
				}
			}
			string response_out = CheckStandardPRComments(PR).ToString();
			string_out = string_out.Split('\n').Where(n => n.Contains(Entry)).FirstOrDefault(); // s.IndexOf(": ");
		//var data = data.Where(p => listOfProducts.Any(l => p.Name == l.Name)).ToList();
		//var matchingKeys = dict.Where(kvp => kvp.Value == 2).Select(kvp => kvp.Key);


		Minimize
		public void picMinimize_Click(object sender, EventArgs e) {
           try
           {
               panelUC.Visible = false;//change visible status of your form, etc.
               this.WindowState = FormWindowState.Minimized; //minimize
               minimizedFlag = true;//set a global flag
           }
           catch (Exception) {

           }

		}

		public void mainForm_Resize(object sender, EventArgs e) {
          ; //check if form is minimized, and you know that this method is only called if and only if the form get a change in size, meaning somebody clicked in the taskbar on your application
			if (minimizedFlag == true) {
				panelUC.Visible = true;    ; //make your panel visible again! thats it
				minimizedFlag = false;     ; //set flag back
			}
		}
	}
*/

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
