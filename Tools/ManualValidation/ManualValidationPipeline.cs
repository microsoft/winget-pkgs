//Copyright 2022-2025 Microsoft Corporation
//Author: Stephen Gillie
//Title: WinGet Approval Pipeline v3.-4.0
//Created: 1/19/2024
//Updated: 3/3/2025
//Notes: Tool to streamline evaluating winget-pkgs PRs. 






/*Contents:
- Init vars
- Boilerplate
- UI top-of-box
	- Menu
- Tabs
- Automation Tools
- PR Tools
- Network Tools
- Validation Starts Here
- Manifests Etc
- VM Image Management
- VM Pipeline Management
- VM Status
- VM Versioning
- VM Orchestration
- File Management
- Reporting
- Clipboard
- Et Cetera
- Utility functions
- Powershell equivalency
- VM Window management
- Event Handlers
- Inject into PRs
- Inject into files
- Misc data

Need work:
1. HourlyRun (pending)
  - LabelAction (needs testing)
    - DefenderFail (pending)
      -  PRStateFromComments (needs rewrite)
    - ADOLog (needs testing)
2. PR Watcher bulk approvals & RandomIEDS (pending)
  - Validation DataGridView needs a function to write to it. 
  - ListingDiff (pending)
  - ManifestListing (pending)
3. ToWork Search & Full ToWork Run (need rewrite)
  - PRStateFromComments (needs rewrite)
4. Every second / 5 seconds - Run Tracker
  - VM Window arrangement (50% rewritten)
  - VM Cycle (pending)
    - GenerateVM (pending)
    - DisgenerateVM (pending)
    - RenameVM (pending)
    - RedoCheckpoint (pending)
    - CheckpointVM (pending)
    - RemoveVMSnapshot (pending)
    - ImportVM (pending)
    - SetVMMemory (pending)
    - RebuildStatus (pending)
  - Automatic VM rotation (pending)
7. Update manifest tools
    - SingleFileAutomation (pending)
    - ManifestAutomation (pending)
    - ManifestFile (pending)
8. AddValidationData - need a form to fill out. (and testing)
9. FullReport (needs testing)
10. AddPRToRecord (needs bugfix)
  - Squash-merge and Closed stats should be higher, but some of the data is “evaporating” before it reaches the logs. 
11. PRReportFromRecord (needs testing)
12. Import new image VM
  - MoveVMStorage (pending)
  - ImageVMMove (pending)
13. Win11 image VM
  - ImageVMStart (pending)
  - ImageVMStop (pending)
14. Update manifest
  - In PR
    - AddDependencyToPR (pending)
    - UpdateHashInPR/2 (pending)
    - UpdateArchInPR (pending)
  - On Disk
    - AddToValidationFile (pending)
    - AddInstallerSwitch (pending)
15. Require admin/UAC (for VMs – might have non-admin mode that uses sandbox instead)
  - OpenSandbox (pending)
16. Preferences (pending)
  - Window arrangement
  - Hourly Mode
  - Warnings
    - Add warnings
  - Enable clipboard watching (manifests/)
  - Enable approvals
  - Enable Waivers?
  - Comment-based moderator controls
  - Use sandbox instead of VMs and don't require Admin/UAC
  - Open VM folder
17. Status bar (pending)
18. PR counters on certain buttons - Approval-Ready, ToWork, Defender, IEDS
19. Buttons/controls foreach VM in VM display: Complete, open PR, open files on disk,  Add dependency (Default VS2015 isf User Input is empty.),  
  - Faster/better to have in-VM controls or in-app controls, or both? Why? 
  - Double-click VM row to bring window to front.
20. Process for adding PackageIdentifier or PR# to VM display.
*/





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//====================--------------------      Init vars     --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
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
        public int build = 931;//Get-RebuildPipeApp
		public string appName = "WinGetApprovalPipeline";
		public string appTitle = "WinGet Approval Pipeline - Build ";
		public static string owner = "microsoft";
		public static string repo = "winget-pkgs";

		public static string remoteIP = Dns.GetHostEntry(Dns.GetHostName()).AddressList.Where(n => n.ToString().Contains("172.")).FirstOrDefault().ToString();
		//PowerShell: $remoteIP = ([ipaddress](($ipconfig[($ipconfig | Select-String "vEthernet").LineNumber..$ipconfig.Length] | Select-String "IPv4 Address") -split ": ")[1]).IPAddressToString
		
		//From VM perspective - for validation script builder.
		public static string RemoteMainFolder = "//"+remoteIP+"/";
		public string SharedFolder = RemoteMainFolder+"/write";

		//Meanwhile, back on the host...
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
		public string Win10Folder = imagesFolder+"\\Win10-Created053025-Original";
		public string Win11Folder = imagesFolder+"\\Win11-Created010424-Original";

		public static string GitHubBaseUrl = "https://github.com/"+owner+"/"+repo;
		public static string GitHubContentBaseUrl = "https://raw.githubusercontent.com/"+owner+"/"+repo;
		public static string GitHubApiBaseUrl = "https://api.github.com/repos/"+owner+"/"+repo;
		public string ADOMSBaseUrl = "https://dev.azure.com/shine-oss";
		
		//ADOLogs - should be refactored to be in-memory.
		public static string DestinationPath = MainFolder+"\\Installers";
		public static string LogPath = DestinationPath+"\\InstallationVerificationLogs\\";
		public static string ZipPath = DestinationPath+"\\InstallationVerificationLogs.zip";

		public string CheckpointName = "Validation";
		public string VMUserName = "user"; //Set to the internal username you're using in your VMs.;
		public string gitHubUserName = "stephengillie";
		//public string SystemRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb;

		public int displayLine = 0;
		
		public static string string_PRRegex = "[0-9]{5,6}";
		public static string string_hashPRRegex = "[#]"+string_PRRegex;
		public static string string_hashPRRegexEnd = string_hashPRRegex+"$";
		public static string string_colonPRRegex = string_PRRegex+"[:]";
		
        public Regex regex_PRRegex = new Regex(@string_PRRegex);
        public Regex regex_hashPRRegex = new Regex(@string_hashPRRegex);
        public Regex regex_hashPRRegexEnd = new Regex(@string_hashPRRegexEnd);
        public Regex regex_colonPRRegex = new Regex(@string_colonPRRegex);
		
		public string file_GitHubToken = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) + "\\Documents\\PowerShell\\ght.txt";
		//public string file_GitHubToken = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) + "\\Documents\\PowerShell\\ght.txt";
		public string GitHubToken;
		public bool TokenLoaded = false;
		public int GitHubRateLimitDelay = 333; // ms
		public int HyperVRateLimitDelay = 3; // seconds

		//JSON
		JavaScriptSerializer serializer = new JavaScriptSerializer();

		//WMI for local VMs
		public ManagementScope scope = new ManagementScope(@"root\virtualization\v2");//, null);
		/* Remote VMs
		var connectionOptions = new ConnectionOptions(
		@"en-US",
		@"domain\user",
		@"password",
		null,
		ImpersonationLevel.Impersonate,
		AuthenticationLevel.Default,
		false,
		null,
		TimeSpan.FromSeconds(5);
		public ManagementScope scope = new ManagementScope(new ManagementPath { Server = "hostnameOrIpAddress", NamespacePath = @"root\virtualization\v2" }, connectionOptions);scope.Connect(); 
		*/

		//ui
		public RichTextBox outBox_msg;
		public System.Drawing.Bitmap myBitmap;//Depreciate
		public System.Drawing.Graphics pageGraphics;//Depreciate?
		public Panel pagePanel;
		public ContextMenuStrip contextMenu1;//Menu?

		public TextBox inputBox_PRNumber, inputBox_User, inputBox_VMRAM;
 		public Label label_VMRAM = new Label();
 		public Label label_User = new Label();
 		public Label label_PRNumber = new Label();
 		public DataGridView dataGridView_vm = new DataGridView();
 		public DataGridView dataGridView_val = new DataGridView();
		public DataTable table_vm = new DataTable();
		public DataTable table_val = new DataTable();
        public Button btn0, btn1, btn2, btn3, btn4, btn5, btn6, btn7, btn8, btn9;
        public Button btn10, btn11, btn12, btn13, btn14, btn15, btn16, btn17, btn18, btn19;
        public Button btn20, btn21, btn22, btn23, btn24, btn25, btn26, btn27, btn28;
		public ToolTip toolTip1, toolTip2, toolTip3, toolTip4;
		
		public StatusStrip statusStrip1;
		public ToolStripStatusLabel toolStripStatusLabel1;

		int DarkMode = 1;//(int)Microsoft.Win32.Registry.GetValue("HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize", "AppsUseLightTheme", -1);
		//0 : dark theme
		//1 : light theme
		//-1 : AppsUseLightTheme could not be found
		
		public Color color_DefaultBack = Color.FromArgb(240,240,240);
		public Color color_DefaultText = Color.FromArgb(0,0,0);
		public Color color_InputBack = Color.FromArgb(255,255,255);
		public Color color_ActiveBack = Color.FromArgb(200,240,240);
		
		int table_vm_Row_Index = 0;
		
		//PRWatch
		public string oldclip = "";
		public string PRTitle = "";

		//Grid
		public static int gridItemWidth = 70;
		public static int gridItemHeight = 45;

		public int lineHeight = 14;
		public int WindowWidth = gridItemWidth*15+20;
		public int WindowHeight = gridItemHeight*12+20;
		
		//Fonts
		string AppFont = "Calibri";
		int AppFontSIze = 12;
		int urlBoxFontSIze = 12;
		string buttonFont = SystemFonts.MessageBoxFont.ToString();
		int buttonFontSIze = 8;





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//====================--------------------    Boilerplate     --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
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
			timer.Tick += new EventHandler(timer_everysecond);
			timer.Start();
			
			this.Text = appTitle + build;
			this.Size = new Size(WindowWidth,WindowHeight);
			//this.StartPosition = FormStartPosition.CenterScreen;

			//this.MaximizeBox = false;
			//this.FormBorderStyle = FormBorderStyle.FixedSingle;
			this.Resize += new System.EventHandler(this.OnResize);
			this.AutoScroll = true;
			Icon icon = Icon.ExtractAssociatedIcon("ManualValidationPipeline.ico");
			this.Icon = icon;
			
		if (DarkMode == 0) {
			color_DefaultBack = Color.FromArgb(33,33,33);
			color_DefaultText = Color.FromArgb(200,200,200);
			color_ActiveBack = Color.FromArgb(15,55,105);
			color_InputBack = Color.FromArgb(0,0,0);
		}
			this.BackColor = color_DefaultBack;
			this.ForeColor = color_DefaultText;
			
			drawMenuBar();
			drawUrlBoxAndGoButton();
			RefreshStatus();
			
        } // end WinGetApprovalPipeline		





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//====================--------------------   UI top-of-box    --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
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

		public void drawRichTextBox(ref RichTextBox richTextBox, int pointX,int pointY,int sizeX,int sizeY,string text, string name){
			richTextBox = new RichTextBox();
			richTextBox.Text = text;
			richTextBox.Name = name;
			richTextBox.Multiline = true;
			richTextBox.AcceptsTab = true;
			richTextBox.WordWrap = true;
			richTextBox.ReadOnly = true;
			richTextBox.DetectUrls = true;
			richTextBox.BackColor = color_DefaultBack;
			richTextBox.ForeColor = color_DefaultText;
			richTextBox.Font = new Font(AppFont, AppFontSIze);
			richTextBox.Location = new Point(pointX, pointY);
			//richTextBox.LinkClicked  += new LinkClickedEventHandler(Link_Click);
			richTextBox.Width = sizeX;
			richTextBox.Height = sizeY;
			//richTextBox.Dock = DockStyle.Fill;
			richTextBox.ScrollBars = System.Windows.Forms.RichTextBoxScrollBars.None;


			//richTextBox.BackColor = Color.Red;
			//richTextBox.ForeColor = Color.Blue;
			//richTextBox.RichTextBoxScrollBars = ScrollBars.Both;
			//richTextBox.AcceptsReturn = true;

			Controls.Add(richTextBox);
		}// end drawRichTextBox
		
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

		public void drawDataGrid(ref DataGridView dataGridView, int startX, int startY, int sizeX, int sizeY){
			dataGridView = new DataGridView();
			dataGridView.ColumnHeadersBorderStyle = DataGridViewHeaderBorderStyle.Raised;
			dataGridView.CellBorderStyle = DataGridViewCellBorderStyle.Single;
			dataGridView.BorderStyle = System.Windows.Forms.BorderStyle.Fixed3D;
			
			dataGridView.ForeColor = color_DefaultText;//Selected cell text color
			dataGridView.BackColor = color_DefaultBack;//Selected cell BG color
			dataGridView.DefaultCellStyle.SelectionForeColor  = color_DefaultText;//Unselected cell text color
			dataGridView.DefaultCellStyle.SelectionBackColor = color_DefaultBack;//Unselected cell BG color
			dataGridView.BackgroundColor = color_DefaultBack;//Space underneath/between cells
			dataGridView.GridColor = SystemColors.ActiveBorder;//Gridline color
			
			dataGridView.Name = "dataGridView";
			dataGridView.Font = new Font(AppFont, AppFontSIze);
			dataGridView.Location = new Point(startX, startY);
			dataGridView.Size = new Size(sizeX, sizeY);
			// dataGridView.KeyUp += dataGridView_KeyUp;
			// dataGridView.Text = text;
			Controls.Add(dataGridView);


		
			dataGridView.EditMode = DataGridViewEditMode.EditProgrammatically;
			dataGridView.AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.DisplayedCellsExceptHeaders;
			dataGridView.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
			dataGridView.AllowUserToDeleteRows = false;
			dataGridView.RowHeadersVisible = false;
			dataGridView.MultiSelect = false;
			//dataGridView.Dock = DockStyle.Fill;

/*
			dataGridView.CellFormatting += new DataGridViewCellFormattingEventHandler(dataGridView_CellFormatting);
			dataGridView.CellParsing += new DataGridViewCellParsingEventHandler(dataGridView_CellParsing);
			addNewRowButton.Click += new EventHandler(addNewRowButton_Click);
			deleteRowButton.Click += new EventHandler(deleteRowButton_Click);
			ledgerStyleButton.Click += new EventHandler(ledgerStyleButton_Click);
			dataGridView.CellValidating += new DataGridViewCellValidatingEventHandler(dataGridView_CellValidating);
*/
		}// end drawDataGrid

		public void drawToolTip(ref ToolTip toolTip, ref Button button, string DisplayText, int AutoPopDelay = 5000, int InitialDelay = 1000, int ReshowDelay = 500){
			toolTip = new ToolTip();

			// Set up the delays for the ToolTip.
			toolTip.AutoPopDelay = AutoPopDelay;
			toolTip.InitialDelay = InitialDelay;
			toolTip.ReshowDelay = ReshowDelay;
			// Force the ToolTip text to be displayed whether or not the form is active.
			toolTip.ShowAlways = true;
			 
			// Set up the ToolTip text for the Button and Checkbox.
			toolTip.SetToolTip(button, DisplayText);
			//toolTip.SetToolTip(this.checkBox1, "My checkBox1");
		}

		public void drawStatusStrip (StatusStrip statusStrip,ToolStripStatusLabel toolStripStatusLabel) {
			statusStrip = new System.Windows.Forms.StatusStrip();
			statusStrip.Dock = System.Windows.Forms.DockStyle.Bottom;
            statusStrip.GripStyle = System.Windows.Forms.ToolStripGripStyle.Visible;
            
			toolStripStatusLabel = new System.Windows.Forms.ToolStripStatusLabel();
			toolStripStatusLabel.Name = "toolStripStatusLabel";
            toolStripStatusLabel.Size = new System.Drawing.Size(109, 17);
            toolStripStatusLabel.Text = "toolStripStatusLabel";
			statusStrip.Items.AddRange(new System.Windows.Forms.ToolStripItem[] { toolStripStatusLabel });
            
            statusStrip.LayoutStyle = System.Windows.Forms.ToolStripLayoutStyle.HorizontalStackWithOverflow;
            statusStrip.Location = new System.Drawing.Point(0, 0);
            statusStrip.Name = "statusStrip";
            statusStrip.ShowItemToolTips = true;
            statusStrip.Size = new System.Drawing.Size(292, 22);
            statusStrip.SizingGrip = false;
            statusStrip.Stretch = false;
            statusStrip.TabIndex = 0;
            statusStrip.Text = "statusStrip";
			
			Controls.Add(statusStrip);
		}
		
		public void drawMenuBar (){
			this.Menu = new MainMenu();
			MenuItem item = new MenuItem("File");
			this.Menu.MenuItems.Add(item);
				item.MenuItems.Add("(disabled) Specify key file location...", new EventHandler(Save_File_Action));
				item.MenuItems.Add("(disabled) Generate daily report", new EventHandler(About_Click_Action));

			item = new MenuItem("Selected VM");
			this.Menu.MenuItems.Add(item);
				item.MenuItems.Add("Complete VM", new EventHandler(Complete_VM_Image_Action));
				item.MenuItems.Add("Relaunch window", new EventHandler(Launch_Window_Image_Action));
				item.MenuItems.Add("Open VM folder", new EventHandler(Open_Folder_Image_Action));
			MenuItem submenu = new MenuItem("WIn10 Image VM");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Generate VM from image", new EventHandler(Generate_Win10_VM_Image_Action)); 
					submenu.MenuItems.Add("Start", new EventHandler(Start_Win10_Image_Action)); 
					submenu.MenuItems.Add("Relaunch window", new EventHandler(Launch_Win10_Window_Image_Action));
					submenu.MenuItems.Add("Stop", new EventHandler(Stop_Win10_Image_Action)); 
					submenu.MenuItems.Add("Turn off", new EventHandler(TurnOff_Win10_Image_Action)); 
					submenu.MenuItems.Add("Attach new image VM", new EventHandler(Attach_Win10_Image_Action)); 
			submenu = new MenuItem("Win11 Image VM");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Generate VM from image", new EventHandler(Generate_Win11_VM_Image_Action)); 
					submenu.MenuItems.Add("Start", new EventHandler(Start_Win11_Image_Action)); 
					submenu.MenuItems.Add("Relaunch window", new EventHandler(Launch_Win11_Window_Image_Action));
					submenu.MenuItems.Add("Stop", new EventHandler(Stop_Win11_Image_Action)); 
					submenu.MenuItems.Add("Turn Off", new EventHandler(TurnOff_Win11_Image_Action)); 
					submenu.MenuItems.Add("Attach new image VM", new EventHandler(Attach_Win11_Image_Action)); 
				item.MenuItems.Add("Disgenerate VM", new EventHandler(Disgenerate_VM_Image_Action));

			item = new MenuItem("Validate Manifest");
			this.Menu.MenuItems.Add(item);
				item.MenuItems.Add("Regular Validation", new EventHandler(Validate_Manifest_Action));
				item.MenuItems.Add("DSC Configure", new EventHandler(Validate_By_Configure_Action));
				item.MenuItems.Add("By PackageIdentifier (User Input)", new EventHandler(Validate_By_ID_Action));
				item.MenuItems.Add("By Arch", new EventHandler(Validate_By_Arch_Action));
				item.MenuItems.Add("By Scope", new EventHandler(Validate_By_Scope_Action));
				item.MenuItems.Add("Both Arch and Scope", new EventHandler(Validate_By_Arch_And_Scope_Action));
			submenu = new MenuItem("Generate manifest for selected VM");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Manifest from clipboard", new EventHandler(Manifest_From_Clipboard));
					submenu.MenuItems.Add("Installer.yaml and the rest from GH", new EventHandler(Single_File_Automation_Action));
			submenu = new MenuItem("Update manifest");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Add dependency (VS2015+)", new EventHandler(Add_Dependency_Disk_Action));
					submenu.MenuItems.Add("Add installer switch (/S)", new EventHandler(Add_Installer_Switch_Action));

			item = new MenuItem("Current PR");
			this.Menu.MenuItems.Add(item);
			submenu = new MenuItem("Approve PR");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Approve PR", new EventHandler(Approved_Action));
			submenu = new MenuItem("Update PR");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("@wingetbot run", new EventHandler(Retry_Action));
					submenu.MenuItems.Add("Label Action", new EventHandler(Label_Action_Action));
					submenu.MenuItems.Add("Check installer", new EventHandler(Check_Installer_Action));
			submenu = new MenuItem("Update manifest");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Add dependency (VS2015+)", new EventHandler(Add_Dependency_Repo_Action));
					submenu.MenuItems.Add("Update hash 'Specified hash doesn't match.'", new EventHandler(Update_Hash_Action));
					submenu.MenuItems.Add("Update hash 2 'SHA256 in manifest...'", new EventHandler(Update_Hash2_Action));
					submenu.MenuItems.Add("Update architecture (x64)", new EventHandler(Update_Arch_Action));
			submenu = new MenuItem("Complete PR");
				item.MenuItems.Add(submenu);
				submenu.MenuItems.Add("Installs Normally in VM", new EventHandler(Manually_Validated_Action));
			submenu = new MenuItem("Wingetbot Close");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Close: Merge Conflicts;", new EventHandler(Merge_Conflicts_Action));
					submenu.MenuItems.Add("Close: Version Already Exists;", new EventHandler(Version_Already_Exiss_Action));
					submenu.MenuItems.Add("Close: Regen with new hash;", new EventHandler(Regen_Hash_Action));
			submenu = new MenuItem("Regular Close");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Close: (User Input);", new EventHandler(Closed_Action));
					submenu.MenuItems.Add("Close: Package still available;", new EventHandler(Package_Available_Action));
					submenu.MenuItems.Add("Close: Duplicate of (User Input);", new EventHandler(Duplicate_Action));
				// item.MenuItems.Add("Add Waiver", new EventHandler(Add_Waiver_Action));
				// item.MenuItems.Add("(disabled) Needs Author Feedback (reason)", new EventHandler(Needs_Author_Feedback_Action));
			// submenu = new MenuItem("Canned Replies");
				// item.MenuItems.Add(submenu);
					// submenu.MenuItems.Add("Automation block", new EventHandler(Automation_Block_Action));
					// submenu.MenuItems.Add("Driver install", new EventHandler(Driver_Install_Action));
					// submenu.MenuItems.Add("Installer missing", new EventHandler(Installer_Missing_Action));
					// submenu.MenuItems.Add("Installer not silent", new EventHandler(Installer_Not_Silent_Action));
					// submenu.MenuItems.Add("Needs PackageUrl", new EventHandler(Needs_PackageUrl_Action));
					// submenu.MenuItems.Add("One manifest per PR", new EventHandler(One_Manifest_Per_PR_Action));
				// item.MenuItems.Add("Record as Project File", new EventHandler(Project_File_Action));
				// item.MenuItems.Add("Record as squash-merge", new EventHandler(Squash_Action));

			item = new MenuItem("Open In Browser");
			this.Menu.MenuItems.Add(item);
				item.MenuItems.Add("Current PR", new EventHandler(Open_Current_PR_Action)); 
				item.MenuItems.Add("PR for selected VM", new EventHandler(Open_PR_Selected_VM_Action)); 
			submenu = new MenuItem("Open many tabs:");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("All PRs on clipboard", new EventHandler(Open_AllUrls_Action)); 
					submenu.MenuItems.Add("Full Approval Run", new EventHandler(Approval_Run_Search_Action));
					submenu.MenuItems.Add("Full ToWork Run", new EventHandler(ToWork_Run_Search_Action));
					submenu.MenuItems.Add("All Start Of Day", new EventHandler(Start_Of_Day_Action));
					submenu.MenuItems.Add("All Resources", new EventHandler(All_Resources_Action));
			submenu = new MenuItem("Start Of Day:");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("WinGet-pkgs repo", new EventHandler(Open_PKGS_Repo_Action));
					submenu.MenuItems.Add("WinGet-cli repo", new EventHandler(Open_CLI_Repo_Action));			submenu = new MenuItem("Resources:");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Gitter chat", new EventHandler(Open_Gitter_Action));
					submenu.MenuItems.Add("Pipeline status", new EventHandler(Open_Pipeline_Action));
					submenu.MenuItems.Add("Dashboard", new EventHandler(Open_Dashboard_Action));
					submenu.MenuItems.Add("Notifications mentions", new EventHandler(Open_Notifications_Action));
					submenu.MenuItems.Add("Approval search", new EventHandler(Approval_Search_Action));
					submenu.MenuItems.Add("Defender search", new EventHandler(Defender_Search_Action)); 
					submenu.MenuItems.Add("ToWork search", new EventHandler(ToWork_Search_Action)); 
				item.MenuItems.Add("Search GitHub for PRs (User Input)", new EventHandler(Pkgs_Search_Action)); 
				item.MenuItems.Add("Approved PR selected below", new EventHandler(Open_SelectedApproved_Action)); 
			
			item = new MenuItem("Help");
			this.Menu.MenuItems.Add(item);
				item.MenuItems.Add("About...", new EventHandler(About_Click_Action));				
				item.MenuItems.Add("VCRedist to dependency...", new EventHandler(VCDependency_Click_Action));				

			this.BackColor = color_DefaultBack;
			this.ForeColor = color_DefaultText;
		}// end drawMenuBar

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
 			int col10 = gridItemWidth*inc;inc++;
 
			//drawStatusStrip(statusStrip1, toolStripStatusLabel1);
			
			table_vm.Columns.Add("vm", typeof(string));
			table_vm.Columns.Add("status", typeof(string));
			table_vm.Columns.Add("version", typeof(int));
			table_vm.Columns.Add("OS", typeof(string));
			table_vm.Columns.Add("Package", typeof(string));
			table_vm.Columns.Add("PR", typeof(int));
			table_vm.Columns.Add("Mode", typeof(string));
			table_vm.Columns.Add("RAM", typeof(double));
			
			table_val.Columns.Add("Timestamp", typeof(string));
			table_val.Columns.Add("PR", typeof(int));
			table_val.Columns.Add("PackageIdentifier", typeof(string));
			table_val.Columns.Add("prVersion", typeof(string));
			table_val.Columns.Add("A", typeof(string));
			table_val.Columns.Add("M", typeof(int));
			table_val.Columns.Add("R", typeof(string));
			table_val.Columns.Add("G", typeof(string));
			table_val.Columns.Add("W", typeof(string));
			table_val.Columns.Add("F", typeof(string));
			table_val.Columns.Add("I", typeof(string));
			table_val.Columns.Add("D", typeof(string));
			table_val.Columns.Add("V", typeof(string));
			table_val.Columns.Add("ManifestVer", typeof(string));
			table_val.Columns.Add("OK", typeof(string));
			
			foreach (DataGridViewColumn column in dataGridView_vm.Columns){
				column.SortMode = DataGridViewColumnSortMode.NotSortable;
			}
			
			drawDataGrid(ref dataGridView_vm, col0, row0, gridItemWidth*7, gridItemHeight*5);
			drawLabel(ref label_PRNumber, col6, row0, gridItemWidth, gridItemHeight,"Current PR:");
			drawUrlBox(ref inputBox_PRNumber, col7, row0, gridItemWidth*2,gridItemHeight,"#000000");
			
			drawLabel(ref label_User, col6, row1, gridItemWidth, gridItemHeight,"User Input:");
			drawUrlBox(ref inputBox_User,col7, row1, gridItemWidth*2,gridItemHeight,"");//UserInput field 
			
			drawLabel(ref label_VMRAM, col6, row2, gridItemWidth, gridItemHeight,"VM RAM:");
			drawUrlBox(ref inputBox_VMRAM,col7, row2, gridItemWidth*2,gridItemHeight,"");//VM RAM display
			
			drawDataGrid(ref dataGridView_val, col0, row5, gridItemWidth*8, gridItemHeight*5);
			//dataGridView_val.Anchor = AnchorStyles.Top | AnchorStyles.Bottom;
			
			drawRichTextBox(ref outBox_msg, col0, row10, this.ClientRectangle.Width,gridItemHeight, "", "outBox_msg");
						
 			drawButton(ref btn10, col6, row3, gridItemWidth, gridItemHeight, "Bulk Approving", Approving_Action);
			drawToolTip(ref toolTip1, ref btn10, "Automatically approve PRs. (Caution - easy to accidentally approve, use with care.)");
			drawButton(ref btn18, col7, row3, gridItemWidth, gridItemHeight, "Individual Validations", Validating_Action);
			drawToolTip(ref toolTip2, ref btn18, "Automatically start manifest in VM.");
 			drawButton(ref btn11, col6, row4, gridItemWidth, gridItemHeight, "Validate Rand IEDS", IEDS_Action);
			drawToolTip(ref toolTip3, ref btn11, "Automatically start manifest for random IEDS in VM.");
			drawButton(ref btn19, col7, row4, gridItemWidth, gridItemHeight, "Idle Mode", Idle_Action);
			drawToolTip(ref toolTip4, ref btn19, "It does nothing.");
			drawButton(ref btn20, col8, row3, gridItemWidth, gridItemHeight, "Testing button", Testing_Action);
			drawButton(ref btn21, col8, row4, gridItemWidth, gridItemHeight, "Testing button 2", Testing2_Action);
			
 	 }// end drawGoButton

		public void OnResize(object sender, System.EventArgs e) {
			//Width - VM and Validation windows adjust with window.
			dataGridView_vm.Width = ClientRectangle.Width - gridItemWidth*3;// - gridItemWidth*2;
			dataGridView_val.Width = ClientRectangle.Width;// - gridItemWidth*2;
			outBox_msg.Width = ClientRectangle.Width;

			inputBox_PRNumber.Left = ClientRectangle.Width - gridItemWidth*2;//col8
			inputBox_User.Left = ClientRectangle.Width - gridItemWidth*2;//col8
			inputBox_VMRAM.Left = ClientRectangle.Width - gridItemWidth*2;//col8
			
			label_PRNumber.Left = ClientRectangle.Width - gridItemWidth*3;//col7
			label_User.Left = ClientRectangle.Width - gridItemWidth*3;//col7
			label_VMRAM.Left = ClientRectangle.Width - gridItemWidth*3;//col7
			
			//Height -Validation and mode buttons adjusts with window.
			btn10.Left = ClientRectangle.Width - gridItemWidth*3;//col7
			btn11.Left = ClientRectangle.Width - gridItemWidth*3;//col7
			btn18.Left = ClientRectangle.Width - gridItemWidth*2;//col8
			btn19.Left = ClientRectangle.Width - gridItemWidth*2;//col8
			btn20.Left = ClientRectangle.Width - gridItemWidth*1;//col9
			btn21.Left = ClientRectangle.Width - gridItemWidth*1;//col9
		}
		//Refresh display and buttons 
		private void timer_everysecond(object sender, EventArgs e) {
			UpdateTableVM();
			RefreshStatus();
			dataGridView_vm.AutoResizeColumns();            
			dataGridView_vm.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.AllCells;
			dataGridView_val.AutoResizeColumns();            
			dataGridView_val.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.AllCells;

		//Hourly Run functionality
		bool HourLatch = false;
		if (Int32.Parse(DateTime.Now.ToString("mm")) == 20 
		&& Int32.Parse(DateTime.Now.ToString("mm")) > 00
		&& Int32.Parse(DateTime.Now.ToString("mm")) < 02) {
			HourLatch = true;
		}
		if (HourLatch) {
			HourLatch = false;
			HourlyRun();
			// if (Int32.Parse(DateTime.Now.ToString("mm")) == 20) {
				// string seconds = DateTime.Now.ToString("ss");
				// Thread.Sleep((60-Int32.Parse(seconds))*1000);//If it's still :20 after, sleep out the minute. 
			// }
		}
			//Update PR display
			string clip = Clipboard.GetText();
			Regex regex = new Regex("^[0-9]{6}$");
			string[] clipSplit = clip.Replace("\r\n","\n").Replace("\n"," ").Replace("/"," ").Replace("#"," ").Replace(";"," ").Split(' ');
			string c = clipSplit.Where(n => regex.IsMatch(n)).FirstOrDefault();
			if (null != c) {
				if (regex.IsMatch(c)) {
					inputBox_PRNumber.Text = "#"+c;
				}
			}

			string Mode = GetMode();
			//Automatic clipboard actions
			regex = new Regex(@"^manifests/");
			if (clip.Contains("Skip to content")) {
				if (Mode == "Validating") {
					//ValidateManifest;
					// Mode | clip
				} else if (Mode == "Approving") {
					PRWatch(false, "Default", "C:\\ManVal\\misc\\ApprovedPRs.txt", "C:\\repos\\winget-pkgs\\Tools\\Review.csv");
				}
			} else if (regex.IsMatch(clip)) {
				Clipboard.SetText("open manifest");	
				string ManifestUrl = GitHubBaseUrl+"/tree/master/"+clip;
				System.Diagnostics.Process.Start(ManifestUrl);
			}

			//Random IEDS mode
			// if ($Mode == "IEDS") {
				// if ((Get-ArraySum (GetStatus()).RAM) < ($SystemRAM*.42)) {
					// RandomIEDS();
				// }
			// }
			
			//Automatic RAM adjustment
			// (Get-VM) | foreach-Object {
				// if(($_.MemoryDemand / $_.MemoryMaximum) -ge 0.9){
					// set-vm -VMName $_.name -MemoryMaximumBytes "$(($_.MemoryMaximum / 1073741824)+2)GB"
				// }
			// }
			

			//CycleVMs();
			//WindowArrange();
			//RotateVMs();
			
		}
		
		public void HourlyRun() {
			Console.Beep(500,250);Console.Beep(500,250);Console.Beep(500,250); //Beep 3x to alert the PC user.
			foreach (string Preset in HourlyRun_PresetList) {
				dynamic Results = SearchGitHub(Preset,1);
				if (Results != null) {
					//foreach (int Result in Results) {
						// LabelAction(Result);
					//}
				}
			}
		}

 		public void RefreshStatus() {
			string Mode = "";
			if (TestPath(TrackerModeFile) == "File") {
				Mode = GetMode();
			}
			if (Mode == "Approving") {
				btn10.BackColor = color_ActiveBack;//Bulk Approving
				btn18.BackColor = color_DefaultBack;//Individual Validations
				btn11.BackColor = color_DefaultBack;//IEDS
				btn19.BackColor = color_DefaultBack;//Idle
			} else if (Mode == "Validating") {
				btn10.BackColor = color_DefaultBack;//Bulk Approving
				btn18.BackColor = color_ActiveBack;//Individual Validations
				btn11.BackColor = color_DefaultBack;//IEDS
				btn19.BackColor = color_DefaultBack;//Idle
			} else if (Mode == "IEDS") {
				btn10.BackColor = color_DefaultBack;//Bulk Approving
				btn18.BackColor = color_DefaultBack;//Individual Validations
				btn11.BackColor = color_ActiveBack;//IEDS
				btn19.BackColor = color_DefaultBack;//Idle
			} else if (Mode == "Idle") {
				btn10.BackColor = color_DefaultBack;//Bulk Approving
				btn18.BackColor = color_DefaultBack;//Individual Validations
				btn11.BackColor = color_DefaultBack;//IEDS
				btn19.BackColor = color_ActiveBack;//Idle
			} else if (Mode == "Config") {
				btn10.BackColor = color_DefaultBack;//Bulk Approving
				btn18.BackColor = color_DefaultBack;//Individual Validations
				btn11.BackColor = color_DefaultBack;//IEDS
				btn19.BackColor = color_DefaultBack;//Idle
			} 
			
			if (TestPath(StatusFile) == "File") {
				double VMRAM = 0;
					try {
				Dictionary<string,object>[] GetStatus = FromCsv(GetContent(StatusFile));
				//Update RAM column and write
				for (int VM = 0; VM < GetStatus.Length -1; VM++) {
					//$_.RAM = Math.Round((Get-VM -Name ("vm"+$_.vm)).MemoryAssigned/1024/1024/1024,2)}
					try {
						VMRAM += Convert.ToDouble(GetStatus[VM]["RAM"]);
					} catch (Exception e) {
						inputBox_VMRAM.Text = "VM"+VM+": "+e.ToString();
					}//end try
				}//end for VM
				} catch {}
				inputBox_VMRAM.Text = VMRAM.ToString();
			}//end if TestPath
		}//end function 

		public void UpdateTableVM() {
			try {
				if (TestPath(StatusFile) == "File") {
				   if (dataGridView_vm.SelectedCells.Count > 0) {//Record the selected row.
						table_vm_Row_Index = dataGridView_vm.SelectedCells[0].RowIndex;
					} else {
						table_vm_Row_Index = 0;
					}
					table_vm.Clear();//Clear the table
					dynamic Status = FromCsv(GetContent(StatusFile, true));
					if (Status != null) {
						for (int r = 1; r < Status.Length -1; r++){
							var rowData = Status[r];//Reload the table
							table_vm.Rows.Add(rowData["vm"], rowData["status"], rowData["version"], rowData["OS"], rowData["Package"], rowData["PR"], rowData["Mode"], rowData["RAM"]);
						}//end for r
					}//end if Status
					dataGridView_vm.DataSource=table_vm;
					dataGridView_vm.Rows[table_vm_Row_Index].Selected = true;//Reselect the row.

					dataGridView_vm.Columns[0].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//vm
					dataGridView_vm.Columns[1].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//status
					dataGridView_vm.Columns[2].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//version
					dataGridView_vm.Columns[3].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//OS
					dataGridView_vm.Columns[4].AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill;//Package
					dataGridView_vm.Columns[5].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//PR
					dataGridView_vm.Columns[6].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//RAM

										dataGridView_val.DataSource=table_val;
					dataGridView_val.Columns[0].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCellsExceptHeader;//Timestamp
					dataGridView_val.Columns[1].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//PR
					dataGridView_val.Columns[2].AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill;//PackageIdentifier
					dataGridView_val.Columns[3].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCellsExceptHeader;//prVersion
					dataGridView_val.Columns[4].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//A
					dataGridView_val.Columns[5].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//R
					dataGridView_val.Columns[6].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//G
					dataGridView_val.Columns[7].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//W
					dataGridView_val.Columns[8].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//F
					dataGridView_val.Columns[9].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//I
					dataGridView_val.Columns[10].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//D
					dataGridView_val.Columns[11].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCells;//V
					dataGridView_val.Columns[12].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCellsExceptHeader;//ManifestVer
					dataGridView_val.Columns[13].AutoSizeMode = DataGridViewAutoSizeColumnMode.ColumnHeader;//OK

				}//end if TestPath
			} catch (Exception e){
				outBox_msg.AppendText(Environment.NewLine + "e: " + e );
			}//end try 
		}//end function






//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//====================--------------------        Tabs        --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public void PRWatch(bool noNew, string Chromatic = "Default", string LogFile = ".\\PR.txt", string ReviewFile = ".\\Review.csv"){
			//$Host.UI.RawUI.WindowTitle = "PR Watcher"//I'm a PR Watcher, watchin PRs go by. 
			string clip = Clipboard.GetText();
			string[] split_clip = clip.Replace("\r\n","\n").Split('\n');
			string replace_clip = clip.Replace("'","").Replace("\"","");
			PRTitle = split_clip.Where(n => regex_hashPRRegexEnd.IsMatch(n)).FirstOrDefault();
			int PR = GetCurrentPR();

			if (PRTitle != "") {
				if (PRTitle != oldclip) {
					//(GetStatus() .Where(n => n["status"] == "ValidationCompleted"} | format-Table);//Drops completed VMs in the middle of the PR approval display.
					//Chromatic was here.
					
					string[] title = PRTitle.Split(':');
					if (title.Length > 1) {
						title = title[1].Split(' ');
					} else {
						title = title[0].Split(' ');
					}
					string Submitter = "";
					try {
						Submitter = split_clip.Where(n => n.Contains("wants to merge")).FirstOrDefault().Split(' ')[0];
					} catch {}
					string InstallerType = YamlValue("InstallerType",clip);

					//Split the title by spaces. Try extracting the version location as the next item after the word "version", and if that fails, use the 2nd to the last item, then 3rd to last, and 4th to last. for some reason almost everyone puts the version number as the last item, and GitHub appends the PR number.
					int prVerLoc = 0;
					for (int i = 0; i < title.Length; i++) {
						if (title[i].Contains("version")) {
							prVerLoc = i;
						}
					}

					string PRVersion = YamlValue("PackageVersion",replace_clip);

					//Get the PackageIdentifier and alert if it matches the auth list.
					string PackageIdentifier = "";
					try {
						PackageIdentifier = YamlValue("PackageIdentifier",replace_clip);
					} catch {
						PackageIdentifier = replace_clip;
					}
					// string matchColor = validColor;




 					string Timestamp = DateTime.Now.ToString("H:mm:ss");
					//Write-Host -nonewline -f $matchColor "| $(Get-Date -format T) | $PR | $(Get-PadRight "PackageIdentifier") | "
					DataRow row = table_val.NewRow();
					row[0] = Timestamp; //Timestamp
					row[1] = PR; //PR (int)
					row[2] =  PackageIdentifier; //PackageIdentifier
					row[3] =  ""; //prVersion
					row[4] =  ""; //A - Auth
					row[5] =  0; //M (int) - Major version difference
					row[6] =  ""; //R - Review file
					row[7] =  ""; //G - aGreements
					row[8] =  ""; //W - Word filter
					row[9] =  ""; //F - apps and Features changed
					row[10] =  ""; //I - InstallerUrl contains PackageVersion
					row[11] =  ""; //D - PR has fewer files than manifest
					row[12] =  ""; //V - Versions remaining
					row[13] =  ""; //ManifestVer
					row[14] =  ""; //OK
					table_val.Rows.InsertAt(row,0);
					int LastRow = 0;//table_val.Rows.Count -1;
					table_val.Rows[LastRow].SetField("PRVersion", PRVersion); 

			
					string ManifestVersion = FindWinGetVersion(PackageIdentifier);
					int PRMajorVersion = Convert.ToInt32(PRVersion.Split('.')[0]);
					int ManifestMajorVersion = 0;
					if (ManifestVersion != "") {
			outBox_msg.AppendText(Environment.NewLine + "ManifestVersion.Split('.') " + ManifestVersion + " PRMajorVersion " + PRMajorVersion);
						ManifestMajorVersion = Convert.ToInt32(ManifestVersion.Split('.')[0]);
					}
			outBox_msg.AppendText(Environment.NewLine + "I'm a PR " + PR + " Watcher, watchin PRs go by.");
						

					//Variable effervescence
					string prAuth = "+";
					string Auth = "A";
					int VersionIncrease = PRMajorVersion - ManifestMajorVersion;//M
					string Review = "R";
					string AgreementAccept = "G";
					string WordFilter = "W";
					string AnF = "F";
					string InstVer = "I";
					string string_ListingDiff = "D";
					int NumVersions = FindWinGetTotalVersions(PackageIdentifier) ; 
					string PRvMan = "P";
					string Approve = "+"; 
					
					string Body = "";

//"PackageIdentifier","gitHubUserName","authStrictness","authUpdateType","autoWaiverLabel","versionParamOverrideUserName","versionParamOverridePR","code200OverrideUserName","code200OverridePR","AgreementOverridePR","AgreementURL","reviewText"
					string strictness = "";
					outBox_msg.AppendText(Environment.NewLine + "PR: " + PR );
					try {
			strictness = GetFileData(DataFileName,PackageIdentifier,"authStrictness");
					} catch {}
					string AuthAccount = "";
					if (strictness != "") {
						try {
			AuthAccount = GetFileData(DataFileName,PackageIdentifier,"gitHubUserName");
					outBox_msg.AppendText(Environment.NewLine + "PR: " + PR + " AuthAccount: " + AuthAccount);
						} catch {}
					}
					if (ManifestVersion == "") {
						PRvMan = "N";
						// matchColor = invalidColor;
						Approve = "-!";
						if (noNew) {
							} else {

							if (regex_hashPRRegex.IsMatch(title[title.Length -1])) {
								// if ((Get-Command ValidateManifest).name) {
									ValidateManifest();
								// } else {
									// Get-Sandbox ($title[-1] -replace"//","");
								// } //end if Get-Command;
							} //end if title;
						} //end if noNew;
					} else if (null != ManifestVersion) {


						 
						 
						if ((Math.Abs(VersionIncrease) > 3) && 
						(!PRTitle.Contains("Automatic deletion")) && 
						(!PRTitle.Contains("Delete")) && 
						(!PRTitle.Contains("Remove")) && 
						(!InstallerType.Contains("portable")) && 
						(AuthAccount != Submitter)) {

							string greaterOrLessThan = "";
								//if VersionIncrease equal = current major version
							if (VersionIncrease < 0) {
								//if VersionIncrease negative = old major version
								greaterOrLessThan = "greater";
							} else if (VersionIncrease > 0) {
								//if VersionIncrease positive = new major version
								greaterOrLessThan = "less";
							}
							Body = "Hi @"+Submitter+",\\n\\n> This PR's version number "+PRVersion+" has major version"+PRMajorVersion+" while the current manifest has major version "+ManifestVersion+". This is a difference of " + Math.Abs(VersionIncrease) + "major versions. Is this intentional?";
							Approve = "-!";
							Body = Body + "\\n\\n(Automated response - build "+build+")\\n<!--\\n[Policy] Needs-Author-Feedback\\n[Policy] Major-Version-Difference\\n-->";
/* 
 							InvokeGitHubPRRequest(PR,"Post","comments",Body,"Silent");
							AddPRToRecord(PR,"Feedback",PRTitle);
					outBox_msg.AppendText(Environment.NewLine + "PR: " + PR + " comments");
					*/
						}
					}
					table_val.Rows[LastRow].SetField("M", VersionIncrease);



					if (strictness != "") {
						string matchVar = "";
							
						foreach (string Account in AuthAccount.Split('/')) {
							if (Account == Submitter) {
								matchVar = "matches";
								Auth = "+";
							} else {
								matchVar = "does not match";
								Auth = "-";
							}
						}
						outBox_msg.AppendText(Environment.NewLine + "PR: " + PR + " matchVar: "+ matchVar);

						if (strictness == "must") {
							Auth += "!";
						}
					}
					if (Auth == "-!") {
						// GetPRApproval(clip,PR,PackageIdentifier);
					outBox_msg.AppendText(Environment.NewLine + "PR: " + PR + " GetPRApproval");
					}
					table_val.Rows[LastRow].SetField("A", Auth);




					
					//Review file only alerts, doesn't block.
				string ReviewData = "";
				try {
					ReviewData = GetFileData(ReviewFile,PackageIdentifier,"Reason");
					if (ReviewData != "") {
					oldclip = PRTitle;
						if (MessageBox.Show(PackageIdentifier + ": " + ReviewData + " - Should this still be approved?", "Question", MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes) {
							Approve = "+";
							Review= "+";
						} else {
							Review= "-";
							Approve = "-";
							// MessageBox.Show("Nothing happens.");
						}
					}
				} catch {}
					table_val.Rows[LastRow].SetField("R", Review);


				//In list, matches PR - explicit pass
				//In list, PR has no Installer.yaml - implicit pass
				//In list, missing from PR - block
				//In list, mismatch from PR - block
				//Not in list or PR - pass
				//Not in list, in PR - alert and pass?
				//Check previous version for omission - depend on wingetbot for now.
				string AgreementUrlFromList = "";
					try {
						AgreementUrlFromList = GetFileData(DataFileName,PackageIdentifier,"AgreementUrl");
					outBox_msg.AppendText(Environment.NewLine + "PR: " + PR + " AgreementUrlFromList: " + AgreementUrlFromList);
					} catch {}
				if (AgreementUrlFromList != "") {
					string AgreementUrlFromClip = YamlValue("AgreementUrl",replace_clip);
					if (AgreementUrlFromClip == AgreementUrlFromList) {
						//Explicit Approve - URL is present and matches.
						AgreementAccept = "+!";
					} else {
						//Explicit mismatch - URL is present and does not match, or URL is missing.
						AgreementAccept = "-!";
						// ReplyToPR(PR,"AgreementMismatch",AgreementUrlFromList);
					}
				} else {
					AgreementAccept = "+";
					//Implicit Approve - your AgreementsUrl is in another file. Can't modify what isn't there. 
				}
					table_val.Rows[LastRow].SetField("G", AgreementAccept);








				if ((!PRTitle.Contains("Automatic deletion")) && 
				(!PRTitle.Contains("Delete")) && 
				(!PRTitle.Contains("Remove")) &&
				(!AgreementAccept.Contains("+"))) {
					outBox_msg.AppendText(Environment.NewLine + "WordFilter: " );

				List<string> WordFilterMatch = null;
					foreach (string word in WordFilterList) {
						// if (clip.Contains(word) && !clip.Contains("Url") && !clip.Contains("Agreement")) {
						if (clip.Contains(word)) {
							WordFilterMatch.Add(word);
						}
					}

					if (WordFilterMatch != null) {
						WordFilter = "-!";
						Approve = "-!";
					outBox_msg.AppendText(Environment.NewLine + "WordFilter: " + WordFilterMatch.FirstOrDefault());
						// ReplyToPR(PR,"WordFilter",WordFilterMatch.FirstOrDefault());
					}
				}
					table_val.Rows[LastRow].SetField("W", WordFilter);





					
					if (null != ManifestVersion) {
						if ((PRvMan != "N") && 
						(!PRTitle.Contains("Automatic deletion")) && 
						(!PRTitle.Contains("Delete")) && 
						(!PRTitle.Contains("Remove"))) {
							/* 
							DisplayName - maybe warn
							DisplayVersion - Hard block
							Publisher - maybe warn
							ProductCode - maybe warn
							UpgradeCode - maybe warn
							InstallerType - maybe warn
							 */

							string replyType = "";
							AnF = "";
							
							foreach (string Entry in AppsAndFeaturesEntriesList) {
								string replyString = "un";
								int entryType = 0;
								if (Entry == "DisplayName") {
									replyString = "dn";
								} else if (Entry == "DisplayVersion") {
									replyString = "dv";
									// entryType = 1;
								// } else if (Entry == "InstallerType") {
									// replyString = "it";
								// } else if (Entry == "Publisher") {
									// replyString = "pu";
								} else if (Entry == "ProductCode") {
									replyString = "pc";
								} else if (Entry == "UpgradeCode") {
									replyString = "uc";
								}

								bool ANFOld = ManifestEntryCheck(PackageIdentifier, ManifestVersion, Entry);
								bool ANFCurrent = clip.Contains(Entry);
								if ((ANFOld == true) && (ANFCurrent == false)) {
									if (entryType == 1) {
										AnF = replyString+"O-";
									}
										replyType = "AppsAndFeaturesMissing";
								} else if ((ANFOld == false) && (ANFCurrent == true)) {
									if (entryType == 1) {
										AnF = replyString+"C-";
									}
									replyType = "AppsAndFeaturesNew";
									//InvokeGitHubPRRequest(PR,"Post","comments","[Policy] Needs-Author-Feedback","Silent")
								} else if ((ANFOld == false) && (ANFCurrent == false)) {
									AnF += replyString+"0";
								} else if ((ANFOld == true) && (ANFCurrent == true)) {
									AnF += replyString+"1";
								}//end if ANFOld
							}//end foreach Entry
							if (replyType != "") {

								// ReplyToPR(PR,replyType,Submitter,MagicLabels[30]);
								// AddPRToRecord(PR,"Feedback",PRTitle);
							}
							
								
						}//end if PRvMan
					}//end if null
					table_val.Rows[LastRow].SetField("F", AnF);





						if ((PRvMan != "N") && 
						(!PRTitle.Contains("Automatic deletion")) && 
						(!PRTitle.Contains("Delete")) && 
						(!PRTitle.Contains("Remove"))) {
						try {
							if (clip.Contains("InstallerUrl")) {
								string InstallerUrl = YamlValue("InstallerUrl",clip);
								////Write-Host "InstallerUrl: InstallerUrl installerMatches PRVersion: -PR PRVersion" -f "blue"
								if (!(InstallerUrl.Contains(PRVersion))) {
									//Matches when the dots are removed from semantec versions in the URL.
									if (!(InstallerUrl.Contains(PRVersion.Replace(".","")))) {
													InstVer = "-";
									}
								}
							}
						} catch {
								InstVer = "-";
						} //end try
					} //end if PRvMan

					try {
						PRVersion = YamlValue("PackageVersion",clip);
						if (PRVersion.Contains(" ")) {
							InstVer = "-!";
						}
					}catch{
						//null = (Get-Process) //This section intentionally left blank.
					}

					table_val.Rows[LastRow].SetField("I", InstVer);


/*
Version Parameter Check - Removed
A = Auth - Done
M = Major version - Done
R = Review - Done
G = aGreement - Done
F = apps and Features - Done in an inefficient fashion that really should be rewritten soon.
W = Word filter - Done
I = version number in InstallerUrl - Done
D = Difference between file counts (PR removes files) - disabled, needs revision
V = highest Version remaining - Done
Manifest version in repo - Done

New UEs
154958 "2024.4.1.152"
155049 "5.1.1.188"
155051 "5.1.1.188"
155060 "4.10.1"
155507 "3.2.38.4985"
156171 (YamlValue)
155850

string to number
155006 ""14""
155193 "7.5.30-Release.5179102"
155266 "c6.76.06"
155353 "1.1.20240415-1"
155354 "1.1.20240415-1"
155593 "v0.7.1"
155642 "v577"
155031 "v576"
155918 "v0.8.0-alpha1"
156200 "V0"
156550 "dev-2024-06"

Returned array instead of string
157466
 */


					if ((PRvMan != "N") && 
					((PRTitle.Contains("Automatic deletion")) || 
					(PRTitle.Contains("Delete")) || 
					(PRTitle.Contains("Remove")))) {//Removal PR - if highest version in repo.
						if ((PRVersion == ManifestVersion) || (NumVersions == 1)) {
	/* 
							ReplyToPR(PR,"VersionCount",Submitter,"[Policy] Needs-Author-Feedback\n[Policy] Highest-Version-Removal");
							AddPRToRecord(PR,"Feedback",PRTitle);
*/
							NumVersions = -1;
						}
					} else {//Addition PR - has more files than repo.
						bool GLD =ListingDiff(clip);// //Ignores when a PR adds files that didn't exist before.
						if (GLD == true) {
							string_ListingDiff = "-!";
/* 
								ReplyToPR(PR,"ListingDiff",GLD);
								InvokeGitHubPRRequest(PR,"Post","comments","[Policy] Needs-Author-Feedback","Silent");
								AddPRToRecord(PR,"Feedback",PRTitle);
 */
						}//end if GLD
					}//end if PRvMan
					table_val.Rows[LastRow].SetField("D", string_ListingDiff);
					table_val.Rows[LastRow].SetField("V", NumVersions);




int comparison = String.Compare(PRVersion, ManifestVersion);

					if (PRvMan != "N") {
						if (null == PRVersion || "" == PRVersion) {
								PRvMan = "Error:PRVersion";
							} else if (ManifestVersion == "Unknown") {
								PRvMan = "Error:ManifestVersion";
							} else if (ManifestVersion == null) {
								PRvMan = "Error:ManifestVersion";
							} else if (comparison < 0) {//PRVersion < ManifestVersion
							PRvMan = ManifestVersion;
						} else if (comparison > 0) {//PRVersion > ManifestVersion
							PRvMan = ManifestVersion;
						} else if (PRVersion == ManifestVersion) {
							PRvMan = "=";
						} else {
								PRvMan = "Error:ManifestVersion";
						}
					}

					if ((Approve == "-!") || 
					(Auth == "-!") || 
					(AnF == "-") || 
					(InstVer == "-!") || 
					(prAuth == "-!") || 
					(string_ListingDiff == "-!") || 
					(NumVersions == -1) || 
					(WordFilter == "-!") || 
					(Review == "-") || 
					(AgreementAccept == "-!") || 
					(PRvMan == "N")) {
					//|| (PRvMan -match "^Error")
						Approve = "-!";
					}

					//PRvMan = PadRight(PRvMan,14);
					table_val.Rows[LastRow].SetField("ManifestVer", PRvMan);





/* 
					if (Approve == "+") {
						ApprovePR(PR);
						AddPRToRecord(PR,"Approved",PRTitle);
					}
*/

					table_val.Rows[LastRow].SetField("OK", Approve);
					dataGridView_val.FirstDisplayedScrollingRowIndex = 0;
					oldclip = PRTitle;
				} //end if PRTitle
			} //end if PRTitle
		} //end function

		public void WorkSearch(string Preset, int Days = 7) {
			int Page = 1;
			dynamic[] PRs = SearchGitHub(Preset,Page,Days,false,true);
			PRs = PRs.Where(n => n["labels"] != null).ToArray();//.Where(n => n["number"] -notin (Get-Status).pr} 
			
			foreach (dynamic FullPR in PRs) {
				int PR = FullPR["number"];
				//Get-TrackerProgress -PR $PR $MyInvocation.MyCommand line PRs.Length
				//line++;
				//This part is too spammy, checking Highest-Version-Removal on every run (sometimes twice a day) for a week as the PR sits. I think this is fixed in the other version. #PendingBugfix
				if((FullPR["title"].Contains("Remove")) || 
				(FullPR["title"].Contains("Delete")) || 
				(FullPR["title"].Contains("Automatic deletion"))){
					CheckInstaller(PR);
				}
				//The other version populates Comments equivalent here, and hands this to both the PRHasNonstandardComments equivalent call, and the PRStateFromComments equivalent below. To halve the number of API calls by reducing redundant calls. This was facilitated by PowerShell's optional typing. 
				//dynamic[] Comments = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Get,"comments"));
				if (Preset == "Approval"){
					if (PRHasNonstandardComments(PR)){
						OpenPRInBrowser(PR);
					//One of these is faster to open, as though one code path has a huge inefficiency. Need more data on which.
					} else {
						OpenPRInBrowser(PR,true);
					}
				} else if (Preset == "Defender"){
					LabelAction(PR);
				} else {//ToWork etc
				//Don't open the PR in browser if UserName (self) was the last commenter, or if it's in the Defender loop. 
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
					if ($Comments[-1].UserName != $gitHubUserName) {
						OpenPRInBrowser(PR);
					}
				}//end if LastCommenter
		*/
				}//end if Preset
			}//end foreach FullPR
		}//end Get-WorkSearch






//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------   Automation Tools  --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public void LabelAction(int PR){
		string[] PRLabels = FromJson(InvokeGitHubPRRequest(PR,"labels","content"))["name"];
			//Write-Output "PR $PR has labels $PRLabels"
			if (PRLabels.Any(n => MagicLabels[0].Contains(n))) {
				DataTable PRState = PRStateFromComments(PR);
				string EightHoursAgo = DateTime.Now.AddHours(-8).ToString("M/d/yyyy");
				string EighteenHoursAgo = DateTime.Now.AddHours(-18).ToString("M/d/yyyy");
		/*
				if (PRState.Where(n => n.Event == "PreValidation")[-1].created_at <  EightHoursAgo && //Last Prevalidation was 8 hours ago.
				PRState.Where(n => n.Event == "Running")[-1].created_at < EighteenHoursAgo) {  //Last Run was 18 hours ago.
					RetryPR(PR);
DataTable dt = ...
DataView dv = new DataView(dt);
dv.RowFilter = "(EmpName != 'abc' or EmpName != 'xyz') and (EmpID = 5)"

dt.where(e => {check something}).Select({select code here})
var query =
    contacts.SelectMany(
        contact => orders.Where(order => order).Select(order )
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
						if (UserInput != null) {
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
						if (UserInput != null) {
							ReplyToPR(PR,"AutoValEnd",UserInput);
							//Get-UpdateHashInPR2 -PR $PR -Clip UserInput
						}
					} else if (Label == MagicLabels[4]) { 
						UserInput = LineFromCommitFile(PR,36,MagicStrings[6],5);
						if (UserInput == null) {
							ReplyToPR(PR,"AutoValEnd",UserInput);
							CheckInstaller(PR);
						}
					} else if (Label == MagicLabels[5]) {
						UserInput = LineFromCommitFile(PR,25,MagicStrings[1]);
						if (UserInput == null) {
							UserInput = LineFromCommitFile(PR,15,MagicStrings[1]);
						}
						if (UserInput != null) {
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
						if (UserInput != null) {
							if (UserInput.Contains("Sequence contains no elements")) {//Reindex fixes this.
								ReplyToPR(PR,"SequenceNoElements");
								string PRTitle = FromJson(InvokeGitHubPRRequest(PR))["title"];
								if ((PRTitle.Contains("Automatic deletion")) || (PRTitle.Contains("Remove"))) {
									ReplyToPR(PR,"InstallsNormally","","Manually-Validated");
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
							AddPRToRecord(PR,"Feedback");
							ReplyToPR(PR,"OneManifestPerPR",MagicLabels[30]);
						}
						if (UserInput == null) {
							ReplyToPR(PR,"AutoValEnd",UserInput);
						}
					} else if (Label == MagicLabels[14]) {
						UserInput = LineFromCommitFile(PR,32,"Validation result: Failed");
						CheckInstaller(PR);
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
						string PRTitle = FromJson(InvokeGitHubPRRequest(PR,""))["title"];
						// foreach (Dictionary<string,object> Waiver in GetFileData(DataFileName,"autoWaiverLabel")) {
							// if (PRTitle.Contains((string)Waiver["PackageIdentifier"])) {
								// AddWaiver(PR);
							// }
						// }
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
			string HaventWorked = "-commenter:"+gitHubUserName+"+";
			string string_nHW = "-label:Hardware+";
			string IEDSLabel = "label:Internal-Error-Dynamic-Scan+";
			string nIEDS = "-"+IEDSLabel;
			string nMMC = "-label:Manifest-Metadata-Consistency+";
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
			
			string Approvable =  "-label:Validation-Merge-Conflict+" ;
			Approvable += "-label:Manifest-Version-Error+";
			Approvable += "-label:Unexpected-File+";
	
			string Workable = "-label:Highest-Version-Removal+";
			Workable += "-label:Manifest-Version-Error+";
			Workable += "-label:Validation-Certificate-Root+";
			Workable += "-label:Binary-Validation-Error+";
			Workable += "-label:Validation-Merge-Conflict+";
			Workable += "-label:Validation-SmartScreen-Error+";
			Workable += "-label:Unexpected-File+";
	
			//Composite settings;
			string Set1 = Blocking + Common + Review1;
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
				Url += Approvable;
				Url += nMMC;
				Url += Workable;
				Url += " sort:created-asc";
			} else if (Preset == "Defender") {
				Url += Defender;
				Url += "sort:updated-asc+";
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
//[Message options: ("AgreementMismatch","AppFail","Approve","AutomationBlock","AutoValEnd","AppsAndFeaturesNew","AppsAndFeaturesMissing","DriverInstall","DefenderFail","HashFailRegen","InstallerFail","InstallerMissing","InstallerNotSilent","NormalInstall","InstallerUrlBad","ListingDiff","ManValEnd","ManifestVersion","NoCause","NoExe","NoRecentActivity","NotGoodFit","OneManifestPerPR","Only64bit","PackageFail","PackageUrl","Paths","PendingAttendedInstaller","PolicyWrapper","RemoveAsk","SequenceNoElements","Unattended","Unavailable","UrlBad","VersionCount","WhatIsIEDS","WordFilter")]
		public string CannedMessage (string Message, string UserInput = "") {
			string string_out = "";
			string Username = "@"+UserInput.Replace(" ","")+",";
			string greeting = "Hi "+ Username + Environment.NewLine + Environment.NewLine;
			//Most of these aren't used frequently enough to store and should be depreciated.
			if (Message == "AgreementMismatch"){
				string_out = greeting  + "This package uses Agreements, but this PR's AgreementsUrl doesn't match the AgreementsUrl on file.";
			} else if (Message == "AppsAndFeaturesNew"){
				string_out = greeting + "This manifest adds Apps and Features entries that aren't present in previous PR versions. This entry should be added to the previous versions, or removed from this version.";
			} else if (Message == "AppsAndFeaturesMissing"){
				string_out = greeting + "This manifest removes Apps and Features entries that are present in previous PR versions. This entry should be added to this version, to maintain version matching, and prevent the 'upgrade always available' situation with this package.";
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
				string_out = "This package installs and launches normally in a Windows 10 VM.";
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
				string_out = "This package installs and launches normally in a Windows 10 VM.";
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

		public string AutoValLog(int PR){
			//int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			//Download
			//Unzip
			//Filter
			//Post
			string string_out = "";
			int DownloadSeconds = 4;
			//StopProcess("photosapp");
			int? BuildNumber = ADOBuildFromPR(PR);
			if (BuildNumber != null) {

				string Url =ADOMSBaseUrl+"/ed6a5dfa-6e7f-413b-842c-8305dd9e89e6/_apis/build/builds/" + BuildNumber + "/artifacts?artifactName=InstallationVerificationLogs&api-version=7.1&%24format=zip";
				System.Diagnostics.Process.Start(Url);//This downloads to Windows default location, which has already been set to DestinationPath
				Thread.Sleep(DownloadSeconds*1000);//Sleep while download completes.

				RemoveItem(LogPath);
				ZipFile.ExtractToDirectory(ZipPath, DestinationPath);
				RemoveItem(ZipPath);
				List<string> UserInput = new List<string>();

				string[] files = Directory.GetFileSystemEntries(LogPath, "*", SearchOption.AllDirectories);
				foreach (string file in files) {
						if (file.Contains("png")) {
							System.Diagnostics.Process.Start(file);
						} //Open PNGs with default app.
							string[] fileContents = GetContent(file).Split('\n');
							UserInput.AddRange(fileContents.Where(n => n.Contains("[FAIL]")).ToList());
							UserInput.AddRange(fileContents.Where(n => n.Contains("error")).ToList());
							UserInput.AddRange(fileContents.Where(n => n.Contains("exception")).ToList());
							UserInput.AddRange(fileContents.Where(n => n.Contains("exit code")).ToList());
							UserInput.AddRange(fileContents.Where(n => n.Contains("fail")).ToList());
							UserInput.AddRange(fileContents.Where(n => n.Contains("No suitable")).ToList());
							UserInput.AddRange(fileContents.Where(n => n.Contains("not supported")).ToList());//not supported by this processor type
							// UserInput += fileContents.Where(n => n.Contains("not applicable")).ToList());
							UserInput.AddRange(fileContents.Where(n => n.Contains("Unable to locate nested installer")).ToList());
							UserInput.AddRange(fileContents.Where(n => n.Contains("Windows cannot install package")).ToList());
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

					string message = "Automatic Validation ended with:" + Environment.NewLine + Environment.NewLine + "> " + string.Join(Environment.NewLine+"> ",UserInput) +Environment.NewLine + Environment.NewLine + Environment.NewLine + "(Automated response - build "+build+".)";

					string_out = ReplyToPR(PR,"", "", "", message);
				} else {
					string message = "Automatic Validation ended with:" + Environment.NewLine + Environment.NewLine + "> No errors to post."+Environment.NewLine + Environment.NewLine + Environment.NewLine +"(Automated response - build "+build+".)";
					string_out = ReplyToPR(PR,"", "", "", message);
				}
			} else {
				string message = "Automatic Validation ended with:" + Environment.NewLine + Environment.NewLine + "> ADO Build not found."+Environment.NewLine + Environment.NewLine +"(Automated response - build "+build+".)";
				string_out = ReplyToPR(PR,"", "", "", message);
			}
			return string_out;
		}

		public void RandomIEDS(int VM = 0){
			if (VM == 0) {
				VM = NextFreeVM();
			}
			dynamic IEDSPRs = SearchGitHub("IEDS");
			int PR = 0;//(IEDSPRs["number"].Where(n => !n.Contains(GetStatus())["pr"]} | Get-Random);
			int File = 0;
			string ManifestType = "";
			string OldManifestType = "";
			while (ManifestType != "version") {
				string string_CommitFile = CommitFile(PR,File);
				string PackageIdentifier = YamlValue("PackageIdentifier",string_CommitFile).Replace("\"","").Replace("'","");
				//ManifestFile(VM,PR,string_CommitFile,PackageIdentifier);
				OldManifestType = ManifestType;
				ManifestType = YamlValue(ManifestType,string_CommitFile);
				//if (OldManifestType == ManifestType) {break};
				File++;
			}	
		}





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//====================--------------------      PR Tools      --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		//Add user to PR: InvokeGitHubPRRequest -Method $Method -Type "assignees" -Data $User -Output StatusDescription
		//Approve PR (needs work): InvokeGitHubPRRequest -PR $PR -Method Post -Type reviews
		public string InvokeGitHubPRRequest(int PR, string Method = WebRequestMethods.Http.Get,string Type = "labels",string Data = "",string Path = "issues") {
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

		public string RetryPR(int PR) {
			AddPRToRecord(PR,"Retry");
			return InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","@wingetbot run");
		}

		public string AddGitHubReviewComment(int PR, string Comment,int? StartLine,int Line) {
			dynamic Commit = FromJson(InvokeGitHubPRRequest(PR, WebRequestMethods.Http.Get, "commits"));
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

		public int ADOBuildFromPR(int PR) {
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

		public void GetPRApproval(string Clip = "",int PR = 0,string PackageIdentifier = ""){
			if (Clip == "") {
				Clip = Clipboard.GetText();
			}
			if (PR == 0) {
				PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			}
			if (PackageIdentifier == "") {
				PackageIdentifier = ((Clip.Split(':'))[1].Split(' ')[0]);
			}
			//Happens only during Bulk Approval, when manifest is in clipboard.
			string auth = GetFileData(DataFileName,PackageIdentifier,"gitHubUserName");
			List<string> Approver = auth.Split('/').Where(n => !n.Contains("(")).ToList();
			string string_joined = string.Join("; @", Approver);
			ReplyToPR(PR,string_joined,"Approve","Needs-Review");
		}

		public string ReplyToPR(int PR,string string_CannedMessage, string string_UserInput = "", string Policy = "", string Body = ""){
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

		public bool PRHasNonstandardComments(int PR) {
			//Check for any non-standard PR comments. Return true if any are non-standard, and false if none are non-standard.
			List<string> list_comments = new List<string>();
			bool out_bool = false;
			dynamic[] comments = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Get,"comments"));
			
			if (comments != null) {
				for (int c = 0; c < comments.Length; c++) {
					list_comments.Add(comments[c]["body"]);
				}
				foreach (string StdComment in StandardPRComments) {
					foreach (string comment in list_comments) {
						if (comment.Contains(StdComment)) {
							list_comments = list_comments.Where(n => n != comment).ToList();
						}
					}
				}
			}
			if (list_comments.Count > 0) {
				out_bool = true;
			}
			return out_bool;
		}

		public DataTable PRStateFromComments(int PR){
			dynamic[] Comments = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Get,"comments")); //| select created_at,@{n="UserName";e={$_.user.login -replace "\[bot\]"}},body)
			//Robot usernames
			string Wingetbot = "wingetbot";
			string AzurePipelines = "azure-pipelines";
			string FabricBot = "microsoft-github-policy-service";
			// List<string> OverallState = new List<string>();
			outBox_msg.AppendText(Environment.NewLine + "PRStateFromComments: "+ Comments.Length);

DataTable OverallState = new DataTable(); 
OverallState.Columns.Add("UserName", typeof(string));
OverallState.Columns.Add("body", typeof(string));
OverallState.Columns.Add("created_at", typeof(DateTime));
OverallState.Columns.Add("State", typeof(string));


			foreach (dynamic Comment in Comments) {
			outBox_msg.AppendText(Environment.NewLine + "Comment "+ ToJson(Comment));
				string State = "";
				string UserName = (string)Comment["user"]["login"];
				string body = (string)Comment["body"];
				//DateTime created_at = TimeZoneInfo.ConvertTimeBySystemTimeZoneId((DateTime)Comment["created_at"], "Pacific Standard Time");
			outBox_msg.AppendText(Environment.NewLine + "State "+ State + "UserName "+ UserName + "body "+ body);

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
				if (string.Equals(UserName, gitHubUserName) && body.Contains("The package didn't pass a Defender or similar security scan")) {
					State = "DefenderFail";
				}
				if (string.Equals(UserName, gitHubUserName) && body.Contains("Status Code: 200")) {
					State = "InstallerAvailable";
				}
				if (string.Equals(UserName, gitHubUserName) && body.Contains("Response status code does not indicate success")) {
					State = "InstallerRemoved";
				}
				if (string.Equals(UserName, gitHubUserName) && body.Contains("which is greater than the current manifest's version")) {
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
				if (string.Equals(UserName, gitHubUserName) && body.Contains("Sequence contains no elements")) {
					State = "SequenceError";
				}
				if (string.Equals(UserName, gitHubUserName) && body.Contains("This manifest has the highest version number for this package")) {
					State = "HighestVersionRemoval";
				}
				if (string.Equals(UserName, gitHubUserName) && body.Contains("SQL error or missing database")) {
					State = "SQLMissingError";
				}
				if (string.Equals(UserName, FabricBot) && body.Contains("The package manager bot determined changes have been requested to your PR")) {
					State = "ChangesRequested";
				}
				if (string.Equals(UserName, FabricBot) && body.Contains("I am sorry to report that the Sha256 Hash does not match the installer")) {
					State = "HashMismatch";
				}
				if (string.Equals(UserName, gitHubUserName) && body.Contains("Automatic Validation ended with:")) {
					State = "AutoValEnd";
				}
				if (string.Equals(UserName, gitHubUserName) && body.Contains("Manual Validation ended with:")) {
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
DataRow newRow = OverallState.NewRow();
newRow["UserName"] = UserName;
newRow["body"] = body;
newRow["created_at"] = Comment["created_at"];
newRow["State"] = State;
OverallState.Rows.Add(newRow);
					// OverallState.Add(State); //| select @{n="event";e={State}},created_at;
				}
			}
			return OverallState;
		}

/*
vm = GetVM(VM);
bool ConnectionStatus = vm.Scope.IsConnected;

*/





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------     Network Tools   --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		//GET = Read; POST = Append; PUT = Overwrite; DELETE = delete
		public string InvokeGitHubRequest(string Url,string Method = WebRequestMethods.Http.Get,string Body = ""){
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

			return response_out;
		}

		public void CheckInstaller(int PR) {
			dynamic Pull = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Get,"files"));
			string PullInstallerContents = DecodeGitHubFile(FromJson(InvokeGitHubRequest(Pull[0]["contents_url"]))["content"]);
			string Url = YamlValue("InstallerUrl",PullInstallerContents);
			string string_out = "Error: Not successful but no error code from internal call.";
			try {
				string_out = "Status code: 200";
				string_out = InvokeWebRequest(Url, "Head");//.StatusCode;
			}catch (Exception err) {
				string_out = err.Message;
			}
			string Body = "URL: "+Url+" \n"+string_out + "\n\n(Automated message - build "+build+")";
			//If ($Body -match "Response status code does not indicate success") {
				//string_out += Get-GitHubPreset InstallerMissing -PR $PR 
			//} //Need this to only take action on new PRs, not removal PRs.
			InvokeGitHubPRRequest(PR, WebRequestMethods.Http.Post, "comments", Body);
		}

		public string FindWinGetVersion(string PackageIdentifier) {
			string string_out = "";	
			string command = "winget search " + PackageIdentifier + " --exact --disable-interactivity";

			Process process = new Process();
			StreamWriter StandardInput;
			StreamReader StandardOut;
			ProcessStartInfo processStartInfo = new ProcessStartInfo("PowerShell.exe");
			processStartInfo.UseShellExecute = false;
			processStartInfo.RedirectStandardInput = true;
			processStartInfo.RedirectStandardOutput = true;
			processStartInfo.RedirectStandardError = true;
			processStartInfo.CreateNoWindow = true;
			process.StartInfo = processStartInfo;
			process.Start();

			StandardInput = process.StandardInput;
			StandardOut = process.StandardOutput;
			StandardInput.AutoFlush = true;
			StandardInput.WriteLine(command);
			StandardInput.Close();
			
			string_out = StandardOut.ReadToEnd();
			try {
				string_out = string_out
				.Split('\n')
				.Where(n => !n.Contains("disable-interactivity"))
				.Where(n => n.ToLower().Contains(PackageIdentifier.ToLower())).FirstOrDefault();
				
				int stringStart = string_out.IndexOf(PackageIdentifier);
				string_out = string_out.Substring(stringStart);
				string_out = string_out.Split(' ')[1];
			} catch {
				string_out = "";
			}
			return string_out;
		}
		
		public int FindWinGetTotalVersions(string PackageIdentifier) {
			string string_out = "";	
			string command = "(((winget search " + PackageIdentifier + " --exact --disable-interactivity --versions --disable-interactivity) -join ',' -replace '-+,','' -split 'Version,')[1] -split ',').count";

			Process process = new Process();
			StreamWriter StandardInput;
			StreamReader StandardOut;
			ProcessStartInfo processStartInfo = new ProcessStartInfo("PowerShell.exe");
			processStartInfo.UseShellExecute = false;
			processStartInfo.RedirectStandardInput = true;
			processStartInfo.RedirectStandardOutput = true;
			processStartInfo.RedirectStandardError = true;
			processStartInfo.CreateNoWindow = true;
			process.StartInfo = processStartInfo;
			process.Start();

			StandardInput = process.StandardInput;
			StandardOut = process.StandardOutput;
			StandardInput.AutoFlush = true;
			StandardInput.WriteLine(command);
			StandardInput.Close();
			
			string_out = StandardOut.ReadToEnd();
			// outBox_msg.AppendText(Environment.NewLine + "Testing2: " + string_out); 
			foreach (string string_in in string_out.Split('\n')) {
				if (string_in.Length > 1 && string_in.Length < 5) {
					string_out = string_in;
				}
			}
			return Convert.ToInt32(string_out);
		}





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================------------------- Validation Starts Here ------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////

public void ValidateManifest(int VM = 0, string PackageIdentifier = "", string PackageVersion = "", int PR = 0, string Arch = "",string Scope = "", string InstallerType = "",string OS = "",string Locale = "",bool InspectNew = false,bool notElevated = false,string MinimumOSVersion = "", string ManualDependency = "", bool NoFiles = false, string installerLine = "", string Operation = "Scan"){
	/* Vaidation orchestration
	Construct WinGet args string and populate script variables.
	- if Configure - skip all of this and just add the Configure file as the WinGet arg.
	Construct the VM script from the script variables and output to commands file.
	- if Configure - Construct a similar script and perform the same output.
	Construct the manifest from the files in the clipboard.
	- if NoFiles, skip.
	Perform new package inspection.
	- if not InspectNew, skip.
	Revert selected VM and launch its window.
	*/
		string clipInput = Clipboard.GetText();
		// [ValidateSet("x86","x64","arm","arm32","arm64","neutral")]
		// [ValidateSet("User","Machine")]
		//PowerShell version passes forward Get-YamlVale's Get-Clipboard call, to get any MinimumOSVersion your clipboard. Because this is only supposed to be run during validation, when you've got the PR with manifest on your clipboard.
		if (OS == "") {
			try{
				var version = YamlValue("MinimumOSVersion", MinimumOSVersion);
				if (Version.Parse(version) >= Version.Parse("10.0.22000.0")){
					OS = "Win11";
				} else{
					OS = "Win10";
				}
			} catch {
				OS = "Win10";
			}
		}
		if (VM == 0) {
			VM = NextFreeVM(OS);//.Replace("vm","");
		}
		if (VM == 0){
		//Write-Host "No available OS VMs";
			GenerateVM(OS);
		//break;
		}
	RevertVM(VM);
		//[ValidateSet("Win10","Win11")]
		//[ValidateSet("Configure","DevHomeConfig","Pin","Scan")]
		int lowerIndex = clipInput.IndexOf("Do not share my personal information") -1;//This is the last visible string at the bottom of the Files page on GitHub. 
		
		string clip = clipInput;
		if (clipInput.Contains("Do not share my personal information")) {
			clip = clipInput.Substring(0,lowerIndex);
		}
		if (clip.Contains("PackageIdentifier: ")) {
			if (PackageIdentifier == "") {
				PackageIdentifier = YamlValue("PackageIdentifier",clip).Replace("\"","").Replace("'","");
			}
		}
		if (clip.Contains("PackageVersion: ")) {
			if (PackageVersion == "") {
				PackageVersion = YamlValue("PackageVersion",clip).Replace("\"","").Replace("'","");
			}
		}
		if (PR == 0) {
			PR = PRNumber(clip,true).FirstOrDefault();
		}
		string RemoteFolder = "//"+remoteIP+"/ManVal/vm/"+VM.ToString();
		if (installerLine == "") {
			installerLine = "--manifest "+RemoteFolder+"/manifest";
		}
		string optionsLine = "";

		string logLine = OS.ToString();
		string nonElevatedShell = "";
		string logExt = "log";
		string VMFolder = MainFolder+"\\vm\\"+VM;
		string manifestFolder = VMFolder+"\\manifest";
		string CmdsFileName = VMFolder+"\\cmds.ps1";
		string packageName = "";
		string wingetArgs = "";

		string archDetect = "";
		string archColor = "yellow";
		string MDLog = "";
		
	if (Operation == "Configure") {
			//Write-Host "Running Manual Config build "build" on vmVM for ConfigureFile"
		wingetArgs = "configure -f "+RemoteFolder+"/manifest/config.yaml --accept-configuration-agreements --disable-interactivity";
		InspectNew = false;
	} else {
		if (PackageIdentifier == "") {
			//Write-Host "Bad PackageIdentifier: "PackageIdentifier""
			//Break;
			Clipboard.SetText(PackageIdentifier);
		}
			//Write-Host "Running Manual Validation build "build" on vmVM for package "PackageIdentifier" version $PackageVersion"
		
		if (PackageVersion != "") {
			logExt = PackageVersion+"."+logExt;
			logLine += "version "+PackageVersion+" ";
		}
		if (Locale != "") {
			logExt = Locale+"."+logExt;
			optionsLine += " --locale "+Locale+" ";
			logLine += "locale "+Locale+" ";
		}
		if (Scope != "") {
			logExt = Scope+"."+logExt;
			optionsLine += " --scope "+Scope+" ";
			logLine += "scope "+Scope+" ";
		}
		if (InstallerType != "") {
			logExt = InstallerType+"."+logExt;
			optionsLine += " --installer-type "+InstallerType+" ";
			logLine += "InstallerType $"+InstallerType+" ";
		}
		string[] Archs = clip.Split(' ')
		.Where(n => !n.Contains("arm"))
		.Where(n => n.Contains("Architecture: ")).ToArray();
		for (int i = 0; i < Archs.Length; i++) {
			Archs[i] = (Archs[i].Split(':'))[1].Trim();
		} 

		if (Archs != null) {
			if (Arch != null) {
				archDetect = "Selected";
			} else {
				Arch = Archs[0];
				archDetect = "Detected";
			}
			archColor = "red";
		}
		if (Arch != "") {
			logExt = Arch+"."+logExt;
				//Write-Host "archDetect Arch Arch of available architectures: Archs" -f archColor
			logLine += Arch+" ";
		}
		if (ManualDependency != "") {
			MDLog = ManualDependency;
				//Write-Host " = = = = Installing manual dependency "+ManualDependency+" = = = = "
			ManualDependency = "Out-Log 'Installing manual dependency "+MDLog+".';Start-Process 'winget' 'install "+MDLog+" --accept-package-agreements --ignore-local-archive-malware-scan' -wait\n";
		}
		// if (notElevated  == true || clip.Contains("ElevationRequirement: elevationProhibited")) {
				//Write-Host " = = = = Detecting de-elevation requirement = = = = "
			// nonElevatedShell = "if ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')){& explorer.exe 'C:\\Program Files\\PowerShell\\7\\pwsh.exe';Stop-Process (Get-Process WindowsTerminal).id}";
			//if elevated, run^^ and exit, else run cmds.
		// }
		packageName = (PackageIdentifier.Split('.'))[1];
		wingetArgs = "install "+optionsLine+" "+installerLine+" --accept-package-agreements --ignore-local-archive-malware-scan";
	}
	List<string> cmdsOut = new List<string>();
/*













*/
// - caret double quote = replace with backslash double quote
// - caret dollarsign = 2nd run remove caret
	if  (Operation == "Configure") {
	cmdsOut.Add(""+nonElevatedShell+"");
	cmdsOut.Add("$TimeStart = Get-Date;");
	cmdsOut.Add("$ConfigurelLogFolder = \""+SharedFolder+"/logs/Configure/$(Get-Date -UFormat %B)/$(Get-Date -Format dd)\"");
	cmdsOut.Add("Function Out-Log ([string]$logData,[string]$logColor='cyan') {");
	cmdsOut.Add("$TimeStamp = (Get-Date -Format T) + ': ';");
	cmdsOut.Add("$logEntry = $TimeStamp + $logData");
	cmdsOut.Add("Write-Host $logEntry -f $logColor;");
	cmdsOut.Add("md $ConfigurelLogFolder -ErrorAction Ignore");
	cmdsOut.Add("$logEntry | Out-File \"$ConfigurelLogFolder/"+PackageIdentifier+"."+logExt+"\" -Append -Encoding unicode");
	cmdsOut.Add("};");
	cmdsOut.Add("Function Out-ErrorData ($errArray,[string]$serviceName,$errorName='errors') {");
	cmdsOut.Add("Out-Log \"Detected $($errArray.count) $serviceName $($errorName): \"");
	cmdsOut.Add("$errArray | ForEach-Object {Out-Log $_ 'red'}");
	cmdsOut.Add("};");
	cmdsOut.Add("Get-TrackerVMSetStatus 'Installing'");
	cmdsOut.Add("Out-Log ' = = = = Starting Manual Validation pipeline build "+build+" on VM "+VM+" Configure file "+logLine+" = = = = '");
	cmdsOut.Add("Out-Log 'Pre-testing log cleanup.'");
	cmdsOut.Add("Out-Log 'Clearing PowerShell errors.'");
	cmdsOut.Add("$Error.Clear()");
	cmdsOut.Add("Out-Log 'Clearing Application Log.'");
	cmdsOut.Add("Clear-EventLog -LogName Application -ErrorAction Ignore");
	cmdsOut.Add("Out-Log 'Clearing WinGet Log folder.'");
	cmdsOut.Add("$WinGetLogFolder = 'C:\\Users\\User\\AppData\\Local\\Packages\\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\\LocalState\\DiagOutputDir'");
	cmdsOut.Add("rm $WinGetLogFolder\\*");
	cmdsOut.Add("Out-Log 'Gathering WinGet info.'");
	cmdsOut.Add("$info = winget --info");
	cmdsOut.Add("Out-ErrorData @($info[0],$info[3],$info[4],$info[5]) 'WinGet' 'infos'");
	cmdsOut.Add("Out-Log \"Main Package Configure with args: "+wingetArgs+"\"");
	cmdsOut.Add("$mainpackage = (Start-Process 'winget' '"+wingetArgs+"' -wait -PassThru);");
	cmdsOut.Add("Out-Log \"$($mainpackage.processname) finished with exit code: $($mainpackage.ExitCode)\";");
	cmdsOut.Add("If ($mainpackage.ExitCode -ne 0) {");
	cmdsOut.Add("Out-Log 'Install Failed.';");
	cmdsOut.Add("explorer.exe $WinGetLogFolder;");
	cmdsOut.Add("Out-ErrorData ((Get-ChildItem $WinGetLogFolder).fullname | ForEach-Object {Get-Content $_ |Where-Object {$_ -match '[[]FAIL[]]' -OR $_ -match 'failed' -OR $_ -match 'error' -OR $_ -match 'does not match'}}) 'WinGet'");
	cmdsOut.Add("Out-ErrorData '"+MDLog+"' 'Manual' 'Dependency'");
	cmdsOut.Add("Out-ErrorData $Error 'PowerShell'");
	cmdsOut.Add("Out-ErrorData (Get-EventLog Application -EntryType Error -after $TimeStart -ErrorAction Ignore).Message 'Application Log'");
	cmdsOut.Add("Out-Log \" = = = = Failing Manual Validation pipeline build "+build+" on VM "+VM+" for Configure file "+logLine+" in $(((Get-Date) -$TimeStart).TotalSeconds) seconds. = = = = \"");
	cmdsOut.Add("Get-TrackerVMSetStatus 'ValidationCompleted'");
	cmdsOut.Add("Break;");
	cmdsOut.Add("}");
	cmdsOut.Add("#Read-Host 'Configure complete, press ENTER to continue...' #Uncomment to examine installer before scanning, for when scanning disrupts the install.");
	cmdsOut.Add("Get-TrackerVMSetStatus 'Scanning'");
	cmdsOut.Add("$WinGetLogs = ((Get-ChildItem $WinGetLogFolder).fullname | ForEach-Object {Get-Content $_ |Where-Object {$_ -match '[[]FAIL[]]' -OR $_ -match 'failed' -OR $_ -match 'error' -OR $_ -match 'does not match'}})");
	cmdsOut.Add("$DefenderThreat = (Get-MPThreat).ThreatName");
	cmdsOut.Add("Out-ErrorData $WinGetLogs 'WinGet'");
	cmdsOut.Add("Out-ErrorData $Error 'PowerShell'");
	cmdsOut.Add("Out-ErrorData (Get-EventLog Application -EntryType Error -after $TimeStart -ErrorAction Ignore).Message 'Application Log'");
	cmdsOut.Add("Out-ErrorData $DefenderThreat \"Defender (with signature version $((Get-MpComputerStatus).QuickScanSignatureVersion))\"");
	cmdsOut.Add("Out-Log \" = = = = Completing Manual Validation pipeline build "+build+" on VM "+VM+" for Configure file "+logLine+" in $(((Get-Date) -$TimeStart).TotalSeconds) seconds. = = = = \"");
	cmdsOut.Add("Get-TrackerVMSetStatus 'ValidationCompleted'");
	
	
	
} else if (Operation == "Scan") {
	
	
	
	cmdsOut.Add(""+nonElevatedShell+"");
	cmdsOut.Add("$TimeStart = Get-Date;");
	cmdsOut.Add("$explorerPid = (Get-Process Explorer).id;");
	cmdsOut.Add("$ManValLogFolder = \""+SharedFolder+"/logs/$(Get-Date -UFormat %B)/$(Get-Date -Format dd)\"");
	cmdsOut.Add("Function Out-Log ([string]$logData,[string]$logColor='cyan') {");
	cmdsOut.Add("$TimeStamp = (Get-Date -Format T) + ': ';");
	cmdsOut.Add("$logEntry = $TimeStamp + $logData");
	cmdsOut.Add("Write-Host $logEntry -f $logColor;");
	cmdsOut.Add("md $ManValLogFolder -ErrorAction Ignore");
	cmdsOut.Add("$logEntry | Out-File \"$ManValLogFolder/"+PackageIdentifier+"."+logExt+"\" -Append -Encoding unicode");
	cmdsOut.Add("};");
	cmdsOut.Add("Function Out-ErrorData ($errArray,[string]$serviceName,$errorName='errors') {");
	cmdsOut.Add("Out-Log \"Detected $($errArray.count) $serviceName $($errorName): \"");
	cmdsOut.Add("$errArray | ForEach-Object {Out-Log $_ 'red'}");
	cmdsOut.Add("};");
	cmdsOut.Add("Get-TrackerVMSetStatus 'Installing'");
	cmdsOut.Add("Out-Log ' = = = = Starting Manual Validation pipeline build "+build+" on VM "+VM+" "+PackageIdentifier+" "+logLine+" = = = = '");
	cmdsOut.Add("Out-Log 'Pre-testing log cleanup.'");
	cmdsOut.Add("Out-Log 'Upgrading installed applications.'");
	cmdsOut.Add("Out-Log (WinGet upgrade --all --include-pinned --disable-interactivity)");
	cmdsOut.Add("Out-Log 'Clearing PowerShell errors.'");
	cmdsOut.Add("$Error.Clear()");
	cmdsOut.Add("Out-Log 'Clearing Application Log.'");
	cmdsOut.Add("Clear-EventLog -LogName Application -ErrorAction Ignore");
	cmdsOut.Add("Out-Log 'Clearing WinGet Log folder.'");
	cmdsOut.Add("$WinGetLogFolder = 'C:\\Users\\User\\AppData\\Local\\Packages\\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\\LocalState\\DiagOutputDir'");
	cmdsOut.Add("rm $WinGetLogFolder\\*");
	cmdsOut.Add("Out-Log 'Updating Defender signature.'");
	cmdsOut.Add("Update-MpSignature");
	cmdsOut.Add("Out-Log 'Gathering WinGet info.'");
	cmdsOut.Add("$info = winget --info");
	cmdsOut.Add("Out-ErrorData @($info[0],$info[3],$info[4],$info[5]) 'WinGet' 'infos'");
	cmdsOut.Add("$InstallStart = Get-Date;");
	cmdsOut.Add(""+ManualDependency+"");
	cmdsOut.Add("Out-Log \"Main Package Install with args: "+wingetArgs+"\"");
	cmdsOut.Add("$mainpackage = (Start-Process 'winget' '"+wingetArgs+"' -wait -PassThru);");
	cmdsOut.Add("Out-Log \"$($mainpackage.processname) finished with exit code: $($mainpackage.ExitCode)\";");
	cmdsOut.Add("$SleepSeconds = 15 #Sleep a few seconds for processes to complete.");
	cmdsOut.Add("if (($InstallStart).AddSeconds($SleepSeconds) -gt (Get-Date)) {");
	cmdsOut.Add("sleep (($InstallStart).AddSeconds($SleepSeconds)-(Get-Date)).totalseconds");
	cmdsOut.Add("} ");
	cmdsOut.Add("$InstallEnd = Get-Date;");
	cmdsOut.Add("If ($mainpackage.ExitCode -ne 0) {");
	cmdsOut.Add("Out-Log 'Install Failed.';");
	cmdsOut.Add("explorer.exe $WinGetLogFolder;");
	cmdsOut.Add("$WinGetLogs = ((Get-ChildItem $WinGetLogFolder).fullname | ForEach-Object {");
	cmdsOut.Add("Get-Content $_ | Where-Object {");
	cmdsOut.Add("$_ -match '[[]FAIL[]]' -OR ");
	cmdsOut.Add("$_ -match 'failed' -OR ");
	cmdsOut.Add("$_ -match 'error' -OR ");
	cmdsOut.Add("$_ -match 'does not match'");
	cmdsOut.Add("}");
	cmdsOut.Add("})");
	cmdsOut.Add("$DefenderThreat = (Get-MPThreat).ThreatName");
	cmdsOut.Add("Out-ErrorData $WinGetLogs 'WinGet'");
	cmdsOut.Add("Out-ErrorData '"+MDLog+"' 'Manual' 'Dependency'");
	cmdsOut.Add("Out-ErrorData $Error 'PowerShell'");
	cmdsOut.Add("Out-ErrorData (Get-EventLog Application -EntryType Error -after $TimeStart -ErrorAction Ignore).Message 'Application Log'");
	cmdsOut.Add("Out-ErrorData $DefenderThreat \"Defender (with signature version $((Get-MpComputerStatus).QuickScanSignatureVersion))\"");
	cmdsOut.Add("Out-Log \" = = = = Failing Manual Validation pipeline build "+build+" on VM "+VM+" for "+PackageIdentifier+" "+logLine+" in $(((Get-Date) -$TimeStart).TotalSeconds) seconds. = = = = \"");
	cmdsOut.Add("if (($WinGetLogs -match '\\[FAIL\\] Installer failed security check.') -OR ");
	cmdsOut.Add("($WinGetLogs -match 'Package hash verification failed') -OR ");
	cmdsOut.Add("($WinGetLogs -match 'Operation did not complete successfully because the file contains a virus or potentially unwanted software')){");
	cmdsOut.Add("Send-SharedError -clip $WinGetLogs");
	cmdsOut.Add("} elseif ($DefenderThreat) {");
	cmdsOut.Add("Send-SharedError -clip $DefenderThreat");
	cmdsOut.Add("} else {");
	cmdsOut.Add("Get-TrackerVMSetStatus 'ValidationCompleted'");
	cmdsOut.Add("}");
	cmdsOut.Add("Break;");
	cmdsOut.Add("}");
	cmdsOut.Add("#Read-Host 'Install complete, press ENTER to continue...' #Uncomment to examine installer before scanning, for when scanning disrupts the install.");
	cmdsOut.Add("Get-TrackerVMSetStatus 'Scanning'");
	cmdsOut.Add("Out-Log 'Install complete, starting file change scan.'");
	cmdsOut.Add("$files = ''");
	cmdsOut.Add("if (Test-Path "+RemoteFolder+"\\files.txt) {#If we have a list of files to run - a relic from before automatic file gathering. ");
	cmdsOut.Add("$files = Get-Content "+RemoteFolder+"\\files.txt");
	cmdsOut.Add("} else {");
	cmdsOut.Add("$files1 = (");
	cmdsOut.Add("Get-ChildItem c:\\ -File -Recurse -ErrorAction Ignore -Force | ");
	cmdsOut.Add("Where-Object {$_.CreationTime -gt $InstallStart} | ");
	cmdsOut.Add("Where-Object {$_.CreationTime -lt $InstallEnd}");
	cmdsOut.Add(").FullName");
	cmdsOut.Add("$files2 = (");
	cmdsOut.Add("Get-ChildItem c:\\ -File -Recurse -ErrorAction Ignore -Force | ");
	cmdsOut.Add("Where-Object {$_.LastAccessTIme -gt $InstallStart} | ");
	cmdsOut.Add("Where-Object {$_.LastAccessTIme -lt $InstallEnd}");
	cmdsOut.Add(").FullName");
	cmdsOut.Add("$files3 = (");
	cmdsOut.Add("Get-ChildItem c:\\ -File -Recurse -ErrorAction Ignore -Force | ");
	cmdsOut.Add("Where-Object {$_.LastWriteTIme -gt $InstallStart} | ");
	cmdsOut.Add("Where-Object {$_.LastWriteTIme -lt $InstallEnd}");
	cmdsOut.Add(").FullName");
	cmdsOut.Add("$files = $files1 + $files2 + $files3 | Select-Object -Unique");
	cmdsOut.Add("}");
	cmdsOut.Add("Out-Log \"Reading $($files.count) file changes in the last $(((Get-Date) -$TimeStart).TotalSeconds) seconds. Starting bulk file execution:\"");
	cmdsOut.Add("$files = $files | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'AppRepository'} |");
	cmdsOut.Add("Where-Object {$_ -notmatch 'assembly'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'CbsTemp'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'CryptnetUrlCache'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'DesktopAppInstaller'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'dotnet'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'dump64a'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'EdgeCore'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'EdgeUpdate'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'EdgeWebView'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'ErrorDialog = ErrorDlg'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'Microsoft.Windows.Search'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'Microsoft\\\\Edge\\\\Application'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'msedge'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'NativeImages'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'Prefetch'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'Provisioning'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'redis'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'servicing'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'System32'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'SysWOW64'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'unins'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'waasmedic'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'Windows Defender'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'Windows Error Reporting'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'WindowsUpdate'} | ");
	cmdsOut.Add("Where-Object {$_ -notmatch 'WinSxS'}");
	cmdsOut.Add("$files | Out-File 'c:\\Users\\user\\Desktop\\ChangedFiles.txt'");
	cmdsOut.Add("$files | Select-String '[.]exe$' | ForEach-Object {if ($_ -match '$packageName') {Out-Log $_ 'green'} else{Out-Log $_ 'cyan'}; try{Start-Process $_}catch{}};");
	cmdsOut.Add("$files | Select-String '[.]msi$' | ForEach-Object {if ($_ -match '$packageName') {Out-Log $_ 'green'} else{Out-Log $_ 'cyan'}; try{Start-Process $_}catch{}};");
	cmdsOut.Add("$files | Select-String '[.]lnk$' | ForEach-Object {if ($_ -match '$packageName') {Out-Log $_ 'green'} else{Out-Log $_ 'cyan'}; try{Start-Process $_}catch{}};");
	cmdsOut.Add("Out-Log \" = = = = End file list. Starting Defender scan.\"");
	cmdsOut.Add("Start-MpScan;");
	cmdsOut.Add("Out-Log \"Defender scan complete, closing windows...\"");
	cmdsOut.Add("Get-Process msedge | Stop-Process");
	cmdsOut.Add("Get-Process mip | Stop-Process");
	cmdsOut.Add("Get-Process powershell | where {$_.id -ne $PID} | Stop-Process");
	cmdsOut.Add("Get-Process explorer | where {$_.id -ne $explorerPid} | Stop-Process");
	cmdsOut.Add("Get-process | Where-Object { $_.mainwindowtitle -ne '' -and $_.processname -notmatch '$packageName' -and $_.processname -ne 'powershell' -and $_.processname -ne 'WindowsTerminal' -and $_.processname -ne 'csrss' -and $_.processname -ne 'dwm'}| Stop-Process");
	cmdsOut.Add("#Get-Process | Where-Object {$_.id -notmatch $PID -and $_.id -notmatch $explorerPid -and $_.processname -notmatch $packageName -and $_.processname -ne 'csrss' -and $_.processname -ne 'dwm'} | Stop-Process");
	cmdsOut.Add("$WinGetLogs = ((Get-ChildItem $WinGetLogFolder).fullname | ForEach-Object {Get-Content $_ |Where-Object {$_ -match '[[]FAIL[]]' -OR $_ -match 'failed' -OR $_ -match 'error' -OR $_ -match 'does not match'}})");
	cmdsOut.Add("$DefenderThreat = (Get-MPThreat).ThreatName");
	cmdsOut.Add("Out-ErrorData $WinGetLogs 'WinGet'");
	cmdsOut.Add("Out-ErrorData '"+MDLog+"' 'Manual' 'Dependency'");
	cmdsOut.Add("Out-ErrorData $Error 'PowerShell'");
	cmdsOut.Add("Out-ErrorData (Get-EventLog Application -EntryType Error -after $TimeStart -ErrorAction Ignore).Message 'Application Log'");
	cmdsOut.Add("Out-ErrorData $DefenderThreat \"Defender (with signature version $((Get-MpComputerStatus).QuickScanSignatureVersion))\"");
	cmdsOut.Add("if (($WinGetLogs -match '\\[FAIL\\] Installer failed security check.') -OR ");
	cmdsOut.Add("($WinGetLogs -match 'Package hash verification failed') -OR ");
	cmdsOut.Add("($WinGetLogs -match 'Operation did not complete successfully because the file contains a virus or potentially unwanted software')){");
	cmdsOut.Add("Send-SharedError -clip $WinGetLogs");
	cmdsOut.Add("Out-Log \" = = = = Failing Manual Validation pipeline build "+build+" on VM "+VM+" for "+PackageIdentifier+" "+logLine+" in $(((Get-Date) -$TimeStart).TotalSeconds) seconds. = = = = \"");
	cmdsOut.Add("Get-TrackerVMSetStatus 'SendStatus'");
	cmdsOut.Add("} elseif ($DefenderThreat) {");
	cmdsOut.Add("Send-SharedError -clip $DefenderThreat");
	cmdsOut.Add("Out-Log \" = = = = Failing Manual Validation pipeline build "+build+" on VM "+VM+" for "+PackageIdentifier+" "+logLine+" in $(((Get-Date) -$TimeStart).TotalSeconds) seconds. = = = = \"");
	cmdsOut.Add("Get-TrackerVMSetStatus 'SendStatus'");
	cmdsOut.Add("} else {");
	cmdsOut.Add("Start-Process PowerShell");
	cmdsOut.Add("Out-Log \" = = = = Completing Manual Validation pipeline build "+build+" on VM "+VM+" for "+PackageIdentifier+" "+logLine+" in $(((Get-Date) -$TimeStart).TotalSeconds) seconds. = = = = \"");
	cmdsOut.Add("Get-TrackerVMSetStatus 'ValidationCompleted'");
	cmdsOut.Add("}");


	}else {
		// Write-Host "Error: Bad Function"
	}
/*












*/
		OutFile(CmdsFileName,string.Join("\n",cmdsOut));

	if (NoFiles == false) {
		//Extract multi-part manifest from clipboard and write to disk
			//Write-Host "Removing previous manifest and adding current..."
		string FilePath = "";
		RemoveItem(manifestFolder,true);
		if (Operation == "Configure") {
			FilePath = manifestFolder+"\\config.yaml";
			OutFile(FilePath,clipInput);
		} else {
			List<string> Files = new List<string>();
			Files.Add("Package.installer.yaml");
			//Gather filenames from PR manifest in clipboard - most PRs, not all.
			string[] FileNames = clip.Replace("\n"," ").Replace("\r"," ").Replace("/"," ").Split(' ').Where(n => n.Contains(".yaml")).ToArray();
			//Get the last file name and chop the .yaml from it, to get the ToReplace string.
			string replace = FileNames[FileNames.Length -1].Replace(".yaml","");
			//Update each filename so it comes out with "Package". 
			for (int i = 0;i < FileNames.Length; i++){
				string string_add = FileNames[i].Replace(replace,"Package");
				Files.Add(string_add);
			}
			//Split out manifest files by the Git double atpersand. 
			string[] split_clip = clip.Replace("@@","∞").Split('∞');
			//foreach files
			for (int i=0;i < Files.Count;i++) {
				string File = Files[i];
				string this_split = split_clip[i*2];
				this_split = this_split.Substring(0,this_split.IndexOf("ManifestVersion") + 22);
				string[] inputObj = this_split.Split('\n');
				
				//Add the manifest folder path to the file path.
				FilePath = manifestFolder+"\\"+File;
				
				//Write-Host "Writing $($inputObj.Length) lines to $FilePath"
				OutFile(FilePath,inputObj);
				
				//Bugfix to catch package identifier appended to last line of last file.
				// string fileContents = GetContent(FilePath);
				string[] fileContents = GetContent(FilePath).Split('\n');
				int fcLen = fileContents.Length -1;
				if (fileContents[fcLen].Contains(PackageIdentifier)) {
					fileContents[fcLen] = (fileContents[fcLen].Replace("PackageIdentifier","∞").Split('∞'))[0];
				}
				fileContents = fileContents.Where(n => !n.Contains("additions & 0 deletions")).ToArray();
				fileContents = fileContents.Where(n => !n.Contains("manifests/")).ToArray();
				fileContents = fileContents.Where(n => !n.Contains("Viewed")).ToArray();
				fileContents = fileContents.Where(n => !n.Contains("marked this conversation as resolved")).ToArray();

				string out_file = string.Join("\n",fileContents);
				OutFile(FilePath,out_file);
			}
			//Get the files just written and extract how many.
			string[] entries = Directory.GetFileSystemEntries(manifestFolder, "*", SearchOption.AllDirectories);
			int filecount = entries.Length;
			// string filedir = "ok";
			// string filecolor = "green";
			// if (filecount < 3) { filedir = "too low"; filecolor = "red";}
			// if (filecount > 3) { filedir = "high"; filecolor = "yellow";}
			// if (filecount > 10) { filedir = "too high"; filecolor = "red";}
				//Write-Host -f $filecolor "File count $filecount is $filedir"
			// if (filecount < 3) { break;}

		}//end if Configure
	}//end if NoFiles

	if (InspectNew == true) {
			//Write-Host "Searching Winget for PackageIdentifier"
		//Write-Host PackageResult
		string PackageResult = FindWinGetVersion(PackageIdentifier);
		if (PackageResult == null) {//"No package found matching input criteria."
			OpenAllURLs(clip);
			System.Diagnostics.Process.Start("https://www.bing.com/search?q="+PackageIdentifier);
			string a = PackageIdentifier.Split('.')[0];
			string b = PackageIdentifier.Split('.')[1];
			if (a != "") {
					//Write-Host "Searching Winget for a"
					// string result_a = FindWinGetVersion(a);
					//Need to refactor these - they're meant to dump into console. 
			}
			if (b != "") {
					//Write-Host "Searching Winget for b"
					// string result_b = FindWinGetVersion(b);
			}
		}//end if PackageResult
	}//end if InspectNew
		//Write-Host "File operations complete, starting VM operations."
	Thread.Sleep(1000);
	SetStatus(VM, "Prevalidation", PackageIdentifier,PR);
	SetVMState("vm"+VM, 2);
	
	LaunchWindow(VM);
}//end manifest



//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------    Manifests Etc    --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
//Section needs refactor badly
		public void SingleFileAutomation(int PR) {//Put installer.yaml on your clipboard and run this, and it gets the other files from the latest manifest, then start validation.
			string clip = Clipboard.GetText();
			string PackageIdentifier = YamlValue("PackageIdentifier",clip);
			string version = YamlValue("PackageVersion",clip).Replace("'","").Replace("\"","");
			List<string> listing = ManifestListing(PackageIdentifier);
			int VM = ManifestFile(PR);
			
			for (int file = 0; file < listing.Count;file++) {
				clip = FileFromGitHub(PackageIdentifier,version,listing[file]);
				ManifestFile(PR, "", "", "", VM,clip);
			}
		}

		public void ManifestAutomation(int VM = 0, int	 PR =0, string Arch = "", string OS = "", string Scope = ""){//Put installler.yaml on your clipboard and run this, then put locale.yaml on your clipboard and press enter, then put the version (.yaml) on your clipboard and press enter, and it will start validation. 
			if (VM == 0){
				VM = NextFreeVM();//.Replace("vm","");
			}
			//Read-Host "Copy Installer file to clipboard, then press Enter to continue."
			string clip = Clipboard.GetText();
			ManifestFile(0,"","","",VM,clip);

			//Read-Host "Copy defaultLocale file to clipboard, then press Enter to continue."
			clip = Clipboard.GetText();
			ManifestFile(0,"","","",VM,clip);

			//Read-Host "Copy version file to clipboard, then press Enter to continue."
			clip = Clipboard.GetText();
			if (Arch != "") {
				ManifestFile(0,Arch,"","",VM,clip);
			} else if (OS != "") {
				ManifestFile(0,"",OS,"",VM,clip);
			} else if (Scope != "") {
				ManifestFile(0,"","",Scope,VM,clip);
			} else {
				ManifestFile(PR,"","","",VM,clip);
			}
		}

		public int ManifestFile(int PR = 0, string Arch = "", string OS = "", string Scope = "", int VM = 0, string clip = ""){//Gets next VM, pulls a flie from the clipboard and puts into the VM's manifest folder, then if it's the Version (.yaml) file, start the VM for validation.  
			if (VM == 0){
				VM = NextFreeVM();//.Replace("vm","");
			}
			if (clip == ""){
				clip = Clipboard.GetText();
			}
			clip = SecondMatch(clip);
			string FileName = "Package";
			string PackageIdentifier = YamlValue("PackageIdentifier",clip).Replace("\"","").Replace("'","");
			string manifestFolder = MainFolder+"\\vm\\"+VM+"\\manifest";
			clip = string.Join("\n",clip.Split('\n').Where(n => !n.Contains("marked this conversation as resolved.")));

			string string_YamlValue = YamlValue("ManifestType",clip);
			if (string_YamlValue == "defaultLocale") {
				string Locale = YamlValue("PackageLocale",clip);
				FileName = FileName+".locale."+Locale;
			} else if (string_YamlValue == "Locale") {
				string Locale = YamlValue("PackageLocale",clip);
				FileName = FileName+".locale."+Locale;
			} else if (string_YamlValue == "installer") {
				RemoveItem(manifestFolder,true);
				FileName = FileName+".installer";
			} else if (string_YamlValue == "version") {
				if (Arch != "") {
					ValidateManifest(VM, PackageIdentifier, "", PR, Arch,"", "","","",false,false,"", "", true);
				} else if (OS != "") {
					ValidateManifest(VM, PackageIdentifier, "", PR, "","", "",OS,"",false,false,"", "", true);
				} else if (Scope != "") {
					ValidateManifest(VM, PackageIdentifier, "", PR, "",Scope, "","","",false,false,"", "", true);
				} else {
					ValidateManifest(VM, PackageIdentifier, "", PR, "","", "","","",false,false,"", "", true);
				}
			}
			string FilePath = manifestFolder+"\\"+FileName+".yaml";
			//Write-Host "Writing (clip.Length) lines to FilePath"
			clip = clip.Replace("0New version: ","0").Replace("0Add version: ","0").Replace("0Add ","0").Replace("0New ","0");
			OutFile(FilePath,clip);
			return VM;
		}

		public List<string> ManifestListing(string PackageIdentifier){
			List<string> string_out = new List<string>();
			try{
				string FirstLetter = PackageIdentifier.ToLower()[0].ToString();
				string Path = PackageIdentifier.Replace(".","/");
				string Version = FindWinGetVersion(PackageIdentifier);
				string Uri = GitHubApiBaseUrl+"/contents/manifests/"+FirstLetter+"/"+Path+"/"+Version+"/";
				dynamic FromGH = FromJson(InvokeGitHubRequest(Uri));
				
				int n = 0;
				foreach (dynamic line in FromGH) {
					n++;
					string_out.Add(line["name"]);
				}
			} catch {
				string_out.Add("Error");
			}
			return string_out;
		}

		public bool ListingDiff(string string_PRManifest){
			string PackageIdentifier = YamlValue("PackageIdentifier", string_PRManifest.Replace("\"",""));

			//Get the lines from the PR manifest containing the filenames.
			string[] array_PRManifest = string_PRManifest.Split('\n')
			.Where(n => n.Contains(".yaml"))
			.Where(n => n.Contains(PackageIdentifier)).ToArray();
			//Go through these and snip the PackageIdentifier, split on slashes, and get the last one.
			for (int i = 0; i < array_PRManifest.Length; i++) {
				string[] swap_array = array_PRManifest[i].Replace(PackageIdentifier+".", "").Split('/');
				array_PRManifest[i] = array_PRManifest[i].Replace(PackageIdentifier+".", "").Split('/')[swap_array.Length - 1];
			}

			bool difference = false;
			if (array_PRManifest.Length > 2){//If there are more than 2 files, so a full multi-part manifest and not just updating ReleaseNotes or ReleaseDate, etc. The other checks for this logic (not deletion PR,etc) are in the main Approval Watch method, so maybe this should join them.
				List<string> CurrentManifest = ManifestListing(PackageIdentifier);
				// string CurrentManifest = string.Join("\n",ManifestListing(PackageIdentifier));
				outBox_msg.AppendText(Environment.NewLine + "CurrentManifest: " + CurrentManifest);
				//Gather the lines from the newest manifest in repo. Counterpart to the above section.
				// if (CurrentManifest == "Error") {
					//If CurrentManifest didn't get any results, (no newest manifest = New package) compare that error with the file list in the PR. 
					// difference = diff CurrentManifest array_PRManifest.Length;
					//Need to rebuild in absence of Compare-Object.
				// } else {
					//But if CurrentManifest did return something, return that. 
				if (array_PRManifest.Length < CurrentManifest.Count){
					difference = true;
				}
			}
			return difference;
		}

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





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------    VM Image Mgmt    --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public void ImageVMStart(string OS = "Win10"){
		//[ValidateSet("Win10","Win11")]
			int VM = 0;
			//RestoreVMSnapshot(VMName);
			//Thread.Sleep(3);
			//SetVMState(VMName,2);
			
			RestoreVMSnapshot(OS);//,OS
			Thread.Sleep(3);
			SetVMState(OS, 2);// ;
			LaunchWindow(VM, OS);//,OS
		}

		public void ImageVMStop(string OS = "Win10"){
			//[ValidateSet("Win10","Win11")]
			int VM = 0;
			string OriginalLoc = "";
			if (OS == "Win10") {
				OriginalLoc = Win10Folder;
			} else if (OS == "Win11") {
				OriginalLoc = Win11Folder;
			}
			//string ImageLoc = "imagesFolder\\OS-image\\";
			int version = GetVMVersion(OS) + 1;
			//Write-Host "Writing OS version version"
			SetVMVersion(version,OS);
			var VMWindows = Process.GetProcessesByName("vmconnect");
			foreach (Process VMWindow in VMWindows){
				if (VMWindow.MainWindowTitle.Contains(OS)) {
				VMWindow.CloseMainWindow();
				}
			}
			RemoveVMSnapshot(OS);
			CheckpointVM(OS);
			StopVM(VM,OS);
			//Write-Host "Letting VM cool..."
			Thread.Sleep(30);
			Process robocopy = new Process();
			robocopy.StartInfo.Arguments = string.Format("/C Robocopy /S {0} {1}", "C:\\source", "C:\\destination");
			robocopy.StartInfo.FileName = "CMD.EXE";
			robocopy.StartInfo.CreateNoWindow = true;
			robocopy.StartInfo.UseShellExecute = false;
			robocopy.Start();
			robocopy.WaitForExit(); 
		}

		public void ImageVMMove(string OS = "Win10"){
			string CurrentVMName = "";
			string timestamp = DateTime.Now.ToString("MMddyy");
			string newLoc = imagesFolder+"\\"+OS+"-Created-"+timestamp+"-original";
					if (OS == "Win10") {
				CurrentVMName = "Windows 10 MSIX packaging environment";
			} else if (OS == "Win11") {
				CurrentVMName = "Windows 11 dev environment";
			}
			//ManagementObject VM = GetVM(CurrentVMName);
			MoveVMStorage(CurrentVMName,newLoc);
			RenameVM(CurrentVMName,OS); 
		}





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------   VM Pipeline Mgmt  --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public void GenerateVM(string OS = "Win10"){

			string vmdata = GetContent(vmCounter);
			int vm = Int32.Parse(vmdata.Replace("\n",""));
			int version = GetVMVersion(OS);
			string destinationPath = imagesFolder+"\\" + vm + "\\";
			string VMFolder = MainFolder + "\\vm\\" + vm;
			string newVmName = "vm" + vm;
			//string startTime = (Get-Date)
					//Write-Host "Creating VM $newVmName version $version OS OS"
			OutFile(vmCounter,(vm + 1).ToString());
			OutFile(StatusFile,"\"" + vm + "\",\"Generating\",\"" + version + "\",\"" + OS + "\",\"\",\"1\",\"0\"",true);
			RemoveItem(destinationPath,true);
			RemoveItem(VMFolder,true);
			string path = imagesFolder+"\\"+OS+"-image\\Virtual Machines\\";
			string VMImageFolder = Directory.GetFileSystemEntries(path, "*.vmcx", SearchOption.AllDirectories)[0];

			//Write-Host "Takes about 120 seconds..."
			ImportVM(VMImageFolder, destinationPath);
			outBox_msg.AppendText(Environment.NewLine + "newVmName "+ newVmName);
			RenameVM(vm.ToString(),newVmName); //(Get-VM | Where-Object {($_.CheckpointFileLocation)+"\\" == $destinationPath}) newName $
			outBox_msg.AppendText(Environment.NewLine + "newVmName "+ newVmName);
			SetVMState(newVmName, 2);// $
			//Remove-VMCheckpoint -VMName $newVmName -Name "Backup"
			RevertVM(vm);
			LaunchWindow(vm);
			//Write-Host "Took $(((Get-Date)-$startTime).TotalSeconds) seconds..."
		}

		public void DisgenerateVM(int vm){
		string destinationPath = "$imagesFolder\\"+vm+"\\";
		string VMFolder = MainFolder+"\\vm\\"+vm;
		string VMName = "vm"+vm;
			
					SetStatus(vm,"Disgenerate");
			var processes = Process.GetProcessesByName("vmconnect");
			foreach (Process process in processes){
				if (process.MainWindowTitle.Contains(VMName)) {
				process.CloseMainWindow();
				}
			}
			StopVM(vm);
			RemoveVM(VMName);

			// string_out = GetStatus();
			// string_out = string_out .Where(n => !n.vm.Contains(VM));
			// Write-Status string_out;

			// int delay = 15
			// 0..$delay | foreach-Object {
				// $pct = $_ / $delay * 100
				// Write-Progress -Activity "Remove VM" -Status "$_ of $delay" -PercentComplete $pct
				// Thread.Sleep(GitHubRateLimitDelay)
			// }
			RemoveItem(destinationPath);
			RemoveItem(VMFolder);
		}

		public void LaunchWindow(int VM = 0, string VMName = ""){
			if (VMName == "") {
				VMName = "vm"+VM;
			}
			var processes = Process.GetProcessesByName("vmconnect");
			foreach (Process process in processes){
				if (process.MainWindowTitle.Contains(VMName)) {
				process.CloseMainWindow();
				}
			}
			var newProcess = new System.Diagnostics.Process();
			newProcess.StartInfo.FileName = "C:\\Windows\\System32\\vmconnect.exe";
			newProcess.StartInfo.Arguments = "localhost " + VMName;
			newProcess.Start();
		}

		public void RevertVM(int VM = 0, string VMName = ""){
			if (VMName == "") {
				VMName = "vm"+VM;
			}
			SetStatus(VM,"Restoring") ;
			RestoreVMSnapshot(VMName);
		}

		public void CompleteVM(int vm){
			string VMFolder = MainFolder+"\\vm\\"+vm;
			string filesFileName = VMFolder+"\\files.txt";
			string VMName = "vm"+vm;
			SetStatus(vm,"Completing", " ", 1);
			var processes = Process.GetProcessesByName("vmconnect");
			foreach (Process process in processes){
				if (process.MainWindowTitle.Contains(VMName)) {
					process.CloseMainWindow();
				}
			}
			try {
				SetVMState("vm"+vm, 3);
			} catch {
				outBox_msg.AppendText(Environment.NewLine + "SetVMState failed for VM: " + vm);
			}
			RemoveItem(filesFileName);
			SetStatus(vm,"Ready","",0,"Ready");
		}

		public void StopVM(int vm,string VMName = ""){
			if (VMName == "") {
				VMName = "vm"+vm;
			} else {
				VMName = vm;
			}
			F(VMName, 3);
		}





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------       VM Status     --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public void SetStatus(int VM, string Status = "", string Package = "",int PR = 0,string Mode = ""){
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
					if (Mode != "") {
						row["Mode"] = Mode;
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
				StopProcess("vmwp");
			}
		}
			
/*public RebuildStatus {
	Status = Get-VM.Where(n => n.name -notmatch "vm0"}|
	Select-Object @{n="vm";e={$_.name}},
	@{n="status";e={"Ready"}},
	@{n="version";e={(GetVMVersion -OS "Win10")}},
	@{n="OS";e={"Win10"}},
	@{n="Package";e={""}},
	@{n="PR";e={"1"}},
	@{n="RAM";e={"0"}}
	OutFile(StatusFile,Status);
}
*/

		public int GetVMPowerState (int VM){
			string VMName = "vm"+VM;
			int Status =0;
			foreach (var property in GetVM(VMName).Properties) {
				if (property.Name == "EnabledState"){
					//HwThreadsPerCoreRealized
					//OnTimeInMilliseconds
					//ProcessID
					Status = Convert.ToInt32(property.Value);
				}
			}
		return Status;
		}




//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------     VM Versioning   --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
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

		public void SetVMVersion(int Version, string OS = "Win10") {
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





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------   VM Orchestration  --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public void VMCycle(){
		Dictionary<string,object>[] VMs = FromCsv(GetContent(StatusFile));
			foreach (Dictionary<string,object> VM in VMs) {
				string Status = (string)VM["status"];
				if (Status == "AddVCRedist") {
					AddToValidationFile((int)VM["vm"]);
				} else if (Status == "Approved") {
					AddWaiver((int)VM["PR"]);
					SetStatus((int)VM["vm"], "Complete");
				} else if (Status == "CheckpointReady") {
					RedoCheckpoint((int)VM["vm"]);
				} else if (Status == "Complete") {
					// if ((VMs .Where(n => n.vm ==((int)VM["vm"])} ).version < (GetVMVersion -OS (int)VM["os"])) {
						// SetStatus((int)VM["vm"],"Regenerate");
					// } else {
						CompleteVM((int)VM["vm"]);
					// }
				} else if (Status == "Disgenerate") {
					DisgenerateVM((int)VM["vm"]);
				} else if (Status == "Revert") {
					RevertVM((int)VM["vm"]);
				} else if (Status == "Regenerate") {
					DisgenerateVM((int)VM["vm"]);
					GenerateVM((string)VM["os"]);
				} else if (Status == "SendStatus") {
					string SharedError = GetContent(SharedErrorFile);
					SharedError = SharedError.Replace("Faulting","\n> Faulting");
					SharedError = SharedError.Replace("2024","\n> 2024");
					SharedError = SharedError.Replace(" (caller: 00007FFA008A5769)","");
					SharedError = SharedError.Replace(" (caller: 00007FFA008AA79F)","");
					SharedError = SharedError.Replace("Exception(1) tid(f1c) 80D02002","");
					SharedError = SharedError.Replace("Exception(2) tid(f1c) 80072EE2     ","");
					SharedError = SharedError.Replace("Exception(4) tid(f1c) 80072EE2     ","");
					SharedError = SharedError.Replace("tid(f1c)","");
					SharedError = SharedError.Replace("C:\\\\__w\\\\1\\\\s\\\\external\\\\pkg\\\\src\\\\AppInstallerCommonCore\\\\Downloader.cpp(185)\\\\WindowsPackageManager.dll!00007FFA008A37C9:","");
					ReplyToPR((int)VM["PR"],"ManValEnd",SharedError); 
					SetStatus((int)VM["vm"],"Complete");
					if ((SharedError.Contains("\\[FAIL\\] Installer failed security check.")) || (SharedError.Contains("Detected 1 Defender"))) {
						//Get-GitHubPreset -Preset DefenderFail -PR VM.PR 
					}
				}; //end switch
			}
		}

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
		Random rnd = new Random(); 
		dynamic VMs = FromCsv(GetContent(StatusFile));
		List<int> VMList = new List<int>();
		for (int r = 1; r < VMs.Length -1; r++){
			dynamic FullVM = VMs[r];
			if (FullVM["OS"] == OS && FullVM["status"] == Status ) {
			//.Where(n => (int)n["version"] < GetVMVersion(OS))
				VMList.Add(Convert.ToInt32(FullVM["vm"]));
			}
		}
		int rand_VM = rnd.Next(VMList.Count -1);
		
		return VMList[rand_VM];
		//Write-Host "No available $OS VMs"
		}//end function

		public void RedoCheckpoint(int vm,string VMName = ""){
			if (VMName == "") {
				VMName = "vm"+vm;
			}
			SetStatus(vm,"Checkpointing");
			RemoveVMSnapshot(VMName);
			CheckpointVM(VMName);
			SetStatus(vm,"Complete");
		}





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------   File Management   --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public string SecondMatch(string clip, int depth = 1) {
			string[] clipArray = clip.Split('\n');
			List<string> sa_out = new List<string>();
			//If $current and $prev don't match, return the $prev element, which is $depth lines below the $current line. Start at clip[$depth] and go until the end - this starts $current at clip[$depth], and $prev gets moved backwards to clip[0] and moves through until $current is at the end of the array, clip[clip.Length], and $prev is $depth previous, at clip[clip.Length - $depth].
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

		public string FileFromGitHub(string PackageIdentifier, string Version, string FileName = "installer.yaml") {
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

		public bool ManifestEntryCheck(string PackageIdentifier, string Version, string Entry = "AppsAndFeaturesEntries"){
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

		public string CommitFile(int PR, int File){
			string url = "";
			dynamic Commit = FromJson(InvokeGitHubPRRequest(PR,"commits","content"));
			if (Commit["files"]["contents_url"].GetType() == "String") {
				url = Commit["files"]["contents_url"];
			} else {
				url = Commit["files"]["contents_url"][File];
			}
			dynamic EncodedFile = FromJson(InvokeGitHubRequest(url));
			return DecodeGitHubFile(EncodedFile["content"]);
		}





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------      Reporting      --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public void AddPRToRecord(int PR, string Action, string Title = ""){
		//[ValidateSet("Approved", "Blocking", "Feedback", "Retry", "Manual", "Closed", "Project", "Squash", "Waiver")]
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





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------      Clipboard      --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public int[] PRNumber(string clip, bool Hash = false){
			string[] string_PRs = null;
			if (Hash == true) {
				string_PRs = clip.Replace("\n"," ").Split(' ').Where(n => regex_hashPRRegex.IsMatch(n)).Distinct().ToArray();
			} else {
				string_PRs = clip.Replace("\n"," ").Split(' ').Where(n => regex_hashPRRegexEnd.IsMatch(n)).ToArray();
			}
			int[] int_PRs = new int[string_PRs.Length];
			for (int n = 0;n < string_PRs.Length; n++) {
				if (Hash == true) {
					string_PRs[n] = string_PRs[n].Replace("#"," ");
				}
				int_PRs[n] = Int32.Parse(string_PRs[n]);
			}
			return int_PRs;
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
			Thread.Sleep(GitHubRateLimitDelay);
			System.Diagnostics.Process.Start(URL);
		}//end Function

		public string YamlValue(string ContainsString, string YamlString){
			//Split YamlString by \n
			//String where equals StringName
			YamlString = YamlString.Split('\n').Where(n => n.Contains(ContainsString)).FirstOrDefault(); // s.IndexOf(": ");
			YamlString = YamlString.Replace(ContainsString+": ","");
			YamlString = YamlString.Split('#')[0];
			//YamlString = (YamlString.ToCharArray().Where(n => n.Contains("\\S"}).Join("");
			return YamlString.Trim();
		}

		public int GetCurrentPR() {
			return Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
		}

		public int GetSelectedVM() {
			return Convert.ToInt32(dataGridView_vm.SelectedRows[0].Cells["vm"].Value);
		}




//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------      Et Cetera      --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
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

		public string GetFileData(string Filename, string PackageIdentifier, string Property){
			dynamic Records = FromCsv(GetContent(Filename));//StatusFile
			string string_out = "";
			for (int r = 1; r < Records.Length -1; r++){
				var row = Records[r];
				if (row["PackageIdentifier"] == PackageIdentifier) {
					string_out += row[Property];
				}//end if row vm
			}//end for r
			return string_out;
		}

		public void AddValidationData(string PackageIdentifier,string gitHubUserName = "",string authStrictness = "",string authUpdateType = "",string autoWaiverLabel = "",string versionParamOverrideUserName = "",int versionParamOverridePR = 0,string code200OverrideUserName = "",int code200OverridePR = 0,int AgreementOverridePR = 0 ,string AgreementURL = "",string reviewText = ""){
		//[ValidateSet("should","must")]
		//[ValidateSet("auto","manual")]
			
			//Find the line with the PackageIdentifier, then if it's null, make a new line and insert.
					dynamic data = FromCsv(GetContent(DataFileName));
					for (int r = 1; r < data.Length -1; r++){
						var row = data[r];
						
						if (row["PackageIdentifier"] == PackageIdentifier) {
							row["gitHubUserName"] = gitHubUserName;
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
				string_out = ( "" | Select-Object "PackageIdentifier","gitHubUserName","authStrictness","authUpdateType","autoWaiverLabel","versionParamOverrideUserName","versionParamOverridePR","code200OverrideUserName","code200OverridePR","AgreementOverridePR","AgreementURL","reviewText")
				string_out.PackageIdentifier = PackageIdentifier
			}

				data += string_out
				data = data.OrderBy(o=>o["PackageIdentifier"]).ToArray();
		*/
				OutFile(DataFileName, ToCsv(data));
		}





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------   Utility Functions  --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public void OpenSandbox(string string_PRNumber){
			int int_PRNumber = 0;
			if (string_PRNumber[0] == '#') {
				int_PRNumber = Int32.Parse(string_PRNumber.Substring(1,string_PRNumber.Length));
			}
			StopProcess("sandbox");
			StopProcess("wingetautomator");
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





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------  PowerShell Equivs  --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
/*Powershell functional equivalency imperatives
		Get-Clipboard = Clipboard.GetText();
		Get-Date = DateTime.Now.ToString("M/d/yyyy");
		Get-Process = public Process[] processes = Process.GetProcesses(); or var processes = Process.GetProcessesByName("Test");
		New-Item = Directory.CreateDirectory(Path) or File.Create(Path);
		Remove-Item = Directory.Delete(Path) or File.Delete(Path);
		Get-ChildItem = string[] entries = Directory.GetFileSystemEntries(path, "*", SearchOption.AllDirectories);
		Start-Process = System.Diagnostics.Process.Start("PathOrUrl");
		Stop-Process = StopProcess("ProcessName");
		Start-Sleep = Thread.Sleep(GitHubRateLimitDelay);
		Get-Random - Random rnd = new Random(); or int month  = rnd.Next(1, 13);  or int card   = rnd.Next(52);
		Create-Archive = ZipFile.CreateFromDirectory(dataPath, zipPath);
		Expand-Archive = ZipFile.ExtractToDirectory(zipPath, extractPath);
		Sort-Object = .OrderBy(n=>n).ToArray(); and -Unique = .Distinct(); Or Array.Sort(strArray); or List
		
		Get-VM = GetVM("VMName");
		Start-VM = SetVMState("VMName", 2);
		Stop-VM = SetVMState("VMName", 4);
		Stop-VM -TurnOff = SetVMState("VMName", 3);
		Reboot-VM = SetVMState("VMName", 10);
		Reset-VM = SetVMState("VMName", 11);
		
*/
		//System
		public void StopProcess(string ProcessName) {
			var processes = Process.GetProcessesByName(ProcessName);
			foreach (Process process in processes){
				process.CloseMainWindow();
			} 
		}
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
		public string GetContent(string Filename, bool NoErrorMessage = false) {
			string string_out = "";
			try {
				// Open the text file using a stream reader.
				using (var sr = new StreamReader(Filename)) {
					// Read the stream as a string, and write the string to the console.
					string_out = sr.ReadToEnd();
				}
			} catch (IOException e) {
				if (NoErrorMessage == false) {
					MessageBox.Show(e.Message, "Error");
				}
			}
			return string_out;
		}

		public void OutFile(string path, object content, bool Append = false) {
			//From SO: Use "typeof" when you want to get the type at compilation time. Use "GetType" when you want to get the type at execution time. "is" returns true if an instance is in the inheritance tree.
			if (TestPath(path) == "None") {
				File.Create(path).Close();
			}
			if (content.GetType() == typeof(string)) {
				string out_content = (string)content;
			//From SO: File.WriteAllLines takes a sequence of strings - you've only got a single string. If you only want your file to contain that single string, just use File.WriteAllText.
				if (Append == true) {
					File.AppendAllText(path, out_content, Encoding.ASCII);//string
				} else {
					File.WriteAllText(path, out_content, Encoding.ASCII);//string
				}
			} else {
				IEnumerable<string> out_content = (IEnumerable<string>)content;
				if (Append == true) {
					File.AppendAllLines(path, out_content, Encoding.ASCII);//IEnumerable<string>'
				} else {
					File.WriteAllLines(path, out_content, Encoding.ASCII);//string[]
				}				
			}
		}

		public string TestPath(string path) {
				string string_out = "";
				if (path != null) {
						path = path.Trim();
					if (Directory.Exists(path)) {
						string_out = "Directory";
					} else if (File.Exists(path)) {
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

			 //Check Headers
			 // for (int i=0; i < response.Headers.Count; ++i)  {
				// outBox_msg.AppendText(Environment.NewLine + "Header Name : " + response.Headers.Keys[i] + "Header value : " + response.Headers[i]);
			 // }

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
					HttpWebResponse response = (HttpWebResponse)request.GetResponse();
					StreamReader sr = new StreamReader(response.GetResponseStream());
					if (Method == "Head") {
						string response_text = response.StatusCode.ToString();
						response_out = response_text;

					} else {
						string response_text = sr.ReadToEnd();
						response_out = response_text;
					}
					sr.Close();
				} catch (Exception e) {
					response_out = "Response Error: " + e.Message;
				}
		return response_out;
		}// end InvokeWebRequest	

		public void RemoveItem(string Path,bool remake = false){
			if (TestPath(Path) == "File") {
				File.Delete(Path);
				if (remake) {
					File.Create(Path);
				}
			} else if (TestPath(Path) == "Directory") {
				Directory.Delete(Path, true);
				if (remake) {
					Directory.CreateDirectory(Path);
				}
			}
		}
		//Hyper-V
		public ManagementObject GetCimService(string ServiceName) {
			string CImQuery = "SELECT * FROM "+ServiceName;
			ObjectQuery QueryData = new ObjectQuery(@CImQuery);
			ManagementObjectSearcher searcher = new ManagementObjectSearcher(scope, QueryData);
			ManagementObjectCollection collection = searcher.Get();

			ManagementObject CimService = null;
			foreach (ManagementObject obj in collection) {
				CimService = obj;
				break;
			}
			return CimService;
		}

		public ManagementObject GetVM(string VMName, string ServiceName = "Msvm_ComputerSystem") {
			return GetCimService(ServiceName + " WHERE ElementName = '" + VMName + "'");
		}
		/*States: 
		1: Other
		2: Start-VM
		3: Stop-VM -TurnOff
		4: Stop-VM
		5: Stopped???
		6: Offline
		7: Test
		8: Defer
		9: Quiesce
		10: Reboot
		11: Reset
		*/
		public void SetVMState(string VMName, int state) {
			ManagementObject vm = GetVM(VMName);
			ManagementBaseObject inParams = vm.GetMethodParameters("RequestStateChange");
			inParams["RequestedState"] = state;
            ManagementBaseObject outParams = vm.InvokeMethod("RequestStateChange", inParams, null);
		}
		
		public void RemoveVM(string VMName) {
			ManagementObject vm = GetVM(VMName);
			ManagementObject virtualSystemService = GetCimService("Msvm_VirtualSystemManagementService");

            ManagementBaseObject inParams = virtualSystemService.GetMethodParameters("DestroyVirtualSystem");
            inParams["ComputerSystem"] = vm.Path.Path;
            ManagementBaseObject outParams = virtualSystemService.InvokeMethod("DestroyVirtualSystem", inParams, null);
		}

        public ManagementObject GetLastSnapshot(string VMName = "") {
			ManagementObject vm = GetVM(VMName);
            ManagementObjectCollection settings = vm.GetRelated(
                "Msvm_VirtualSystemSettingData",
                "Msvm_MostCurrentSnapshotInBranch",
                null,
                null,
                "Dependent",
                "Antecedent",
                false,
                null);

            ManagementObject virtualSystemsetting = null;
            foreach (ManagementObject setting in settings) {
                //Console.WriteLine(setting.Path.Path);
                //Console.WriteLine(setting["ElementName"]);
                virtualSystemsetting = setting;
            }
            return virtualSystemsetting;
        }

		public void RestoreVMSnapshot(string VMName) {
			try {
				
			ManagementObject snapshot = GetLastSnapshot(VMName);
			ManagementObject snapshotService = GetCimService("Msvm_VirtualSystemSnapshotService");

			var inParameters = snapshotService.GetMethodParameters("ApplySnapshot");
			inParameters["Snapshot"] = snapshot.Path.Path;
			var outParameters = snapshotService.InvokeMethod("ApplySnapshot", inParameters, null);
			//return (uint)outParameters["ReturnValue"];
			} catch (Exception e) {
				outBox_msg.AppendText(Environment.NewLine + "e: " + e );
			}
		}
		
		public uint CheckpointVM(string VMName) {
			ManagementObject snapshot = GetLastSnapshot(VMName);
			ManagementObject snapshotService = GetCimService("Msvm_VirtualSystemSnapshotService");

			var inParameters = snapshotService.GetMethodParameters("CreateSnapshot");
			inParameters["Snapshot"] = snapshot.Path.Path;
			var outParameters = snapshotService.InvokeMethod("CreateSnapshot", inParameters, null);
			return (uint)outParameters["ReturnValue"];
		}
		
		public uint RemoveVMSnapshot(string VMName) {
			ManagementObject snapshot = GetLastSnapshot(VMName);
			ManagementObject snapshotService = GetCimService("Msvm_VirtualSystemSnapshotService");

			var inParameters = snapshotService.GetMethodParameters("DestroySnapshot");
			inParameters["Snapshot"] = snapshot.Path.Path;
			var outParameters = snapshotService.InvokeMethod("DestroySnapshot ", inParameters, null);
			return (uint)outParameters["ReturnValue"];
		} 
		
		public void RenameVM(string VMName, string NewName) {
			Process process = new Process();
			string command = "Rename-VM -VM "+VMName+" -newName "+NewName;
			process.StartInfo.Arguments = string.Format(command);
			process.StartInfo.FileName = "PowerShell.EXE";
			process.StartInfo.CreateNoWindow = true;
			process.StartInfo.UseShellExecute = false;
			process.Start();
			process.WaitForExit(); 
		}
			
		public void RenameVM2(string VMName, string vmNewName) {
	  
            ManagementObject virtualSystemService = GetCimService("Msvm_VirtualSystemManagementService");
            ManagementBaseObject inParams = virtualSystemService.GetMethodParameters("ModifyVirtualSystem");
			ManagementObject vm = GetVM(VMName);
			// ManagementBaseObject inParams = vm.GetMethodParameters("ModifyVirtualSystem");
	
            inParams["ComputerSystem"] = vm.Path.Path;
            ManagementObject settingData  = null;
            ManagementObjectCollection settingsData = vm.GetRelated( 
																"Msvm_VirtualSystemSettingData",
																 "Msvm_SettingsDefineState",
																 null,
																 null,
																 "SettingData",
																 "ManagedElement",
																 false,
																 null);

            foreach (ManagementObject data in settingsData) {
                settingData = data;
            }
            settingData["ElementName"] = vmNewName;
            inParams["SystemsettingData"] = settingData.GetText(TextFormat.CimDtd20);
            ManagementBaseObject outParams = virtualSystemService.InvokeMethod("ModifyVirtualSystem", inParams, null);
            // ManagementBaseObject outParams = vm.InvokeMethod("RequestStateChange", inParams, null);

        }
		
		public void MoveVMStorage(string VMName, string DestinationPath) {
			Process process = new Process();
			string command = "Move-VMStorage -VM "+VMName+" -DestinationStoragePath "+DestinationPath;
			process.StartInfo.Arguments = string.Format(command);
			process.StartInfo.FileName = "PowerShell.EXE";
			process.StartInfo.CreateNoWindow = true;
			process.StartInfo.UseShellExecute = false;
			process.Start();
			process.WaitForExit(); 
		}
		
		public void ImportVM(string CurrentPath, string DestinationPath) {
			Process process = new Process();
			string command = "Import-VM -Path " + CurrentPath + "  -Copy -GenerateNewId -VhdDestinationPath "+DestinationPath +" -VirtualMachinePath "+DestinationPath;
			process.StartInfo.FileName = "PowerShell.EXE";
			process.StartInfo.Arguments = command;
			process.StartInfo.CreateNoWindow = true;
			process.StartInfo.UseShellExecute = false;
			outBox_msg.AppendText(Environment.NewLine + "ImportVM " + process.StartInfo.FileName);
			process.Start();
			outBox_msg.AppendText(Environment.NewLine + "Start " + process.StartInfo.FileName);
			process.WaitForExit(); 
			outBox_msg.AppendText(Environment.NewLine + "WaitForExit " + process.StartInfo.FileName);
		} 

		public void SetVMMemory(string VMName, int MemoryMaximumGB) {
			Process process = new Process();
			string command = "Set-VM -VMName " + VMName + "  -MemoryMaximumBytes " + ((MemoryMaximumGB + 2) * 1073741824);
			process.StartInfo.Arguments = string.Format(command);
			process.StartInfo.FileName = "PowerShell.EXE";
			process.StartInfo.CreateNoWindow = true;
			process.StartInfo.UseShellExecute = false;
			process.Start();
			process.WaitForExit(); 
		}





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------   Window Locations  --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
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

		public void  WindowLoc(int vm,ref RECT rect) {
			//Need to readd the logic that finds the mainwindowhandle from the VM number.
			var processes = Process.GetProcessesByName("vmconnect");
			string VMName = "vm"+vm;
			foreach (Process process in processes){
				if (process.MainWindowTitle ==(VMName)) {
					GetWindowRect(process.MainWindowHandle,out rect);
				}
			}
		}

		public void  WindowSet(int vm,int Left,int Top,int Right,int Bottom) {
			var processes = Process.GetProcessesByName("vmconnect");
			string VMName = "vm"+vm;
			foreach (Process process in processes){
				if (process.MainWindowTitle ==(VMName)) {
					MoveWindow(process.MainWindowHandle,Left,Top,Right,Bottom,true);
				}
			}
		}

		public void  WindowArrange() {
			Dictionary<string,object>[] GetStatus = FromCsv(GetContent(StatusFile));

			Dictionary<string,object>[] VMs = (Dictionary<string,object>[])GetStatus.Where(n => (string)n["status"] != "Ready").Select(n => n["vm"]);

			if (VMs != null) {
				int n = 0;
				//for (int n = 1;n < VMs.Length;n++) {
				foreach (Dictionary<string,object> FullVM in VMs){
				RECT Base = new RECT();
				int VM = (int)FullVM["vm"];
				if (n == 0) {
					WindowSet(VM,900,0,1029,860);
					WindowLoc(VM, ref Base);
				}
					
					int Left = (Base.Left - (100 * n));
					int Top = (Base.Top + (66 * n));
					WindowSet(VM,Left,Top,1029,860);
				n++;
				}
			}

				for (int VM = 0; VM < GetStatus.Length; VM++) {
					try {
						string string_ram = GetStatus[VM]["RAM"]+" ";
					} catch {
						//inputBox_VMRAM.Text = e.ToString();
					}
				}
		}





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------    Event Handlers   --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		//File
		public void Save_File_Action(object sender, EventArgs e) {
			MessageBox.Show("You're saved");
		}// end Save_File_Action

		public void Daily_Report_Action(object sender, EventArgs e) {
			PRFullReport();
		}// end Daily_Report_Action

		//VM Lifecycle
		public void Complete_VM_Image_Action (object sender, EventArgs e) {
			CompleteVM(GetSelectedVM());
		} // end Complete_VM_Image_Action

		public void Launch_Window_Image_Action (object sender, EventArgs e) {
			LaunchWindow(GetSelectedVM());
		} // end Launch_Window_Image_Action

		public void Open_Folder_Image_Action (object sender, EventArgs e) {
			int VM = GetSelectedVM();
			Process.Start("C:\\ManVal\\vm\\"+VM.ToString());
		} // end Launch_Window_Image_Action
		//VM Lifecycle - Win10
		public void Generate_Win10_VM_Image_Action (object sender, EventArgs e) {
			GenerateVM("Win10");
		} // end Generate_VM_Image_Action

		public void Start_Win10_Image_Action (object sender, EventArgs e) {
			ImageVMStart("Win10");
		} // end Start_Win10_Image_Action

		public void Launch_Win10_Window_Image_Action (object sender, EventArgs e) {
			LaunchWindow(0,"Win10");
		} // end Launch_Win10_Window_Image_Action

		public void Stop_Win10_Image_Action (object sender, EventArgs e) {
			ImageVMStop("Win10");
		} // end Stop_Win10_Image_Action

		public void TurnOff_Win10_Image_Action (object sender, EventArgs e) {
			StopVM(0,"Win10");
		} // end TurnOff_Win10_Image_Action

		public void Attach_Win10_Image_Action (object sender, EventArgs e) {
			ImageVMMove("Win10");
		} // end Attach_Win10_Image_Action
		//VM Lifecycle - Win11
		public void Generate_Win11_VM_Image_Action (object sender, EventArgs e) {
			GenerateVM("Win11");
		} // end Generate_VM_Image_Action

		public void Start_Win11_Image_Action (object sender, EventArgs e) {
			ImageVMStart("Win11");
		} // end Start_Win11_Image_Action

		public void Launch_Win11_Window_Image_Action (object sender, EventArgs e) {
			LaunchWindow(0,"Win11");
		} // end Launch_Win11_Window_Image_Action

		public void Stop_Win11_Image_Action (object sender, EventArgs e) {
			ImageVMStop("Win11");
		} // end Stop_Win11_Image_Action

		public void TurnOff_Win11_Image_Action (object sender, EventArgs e) {
			StopVM(0,"Win11");
		} // end TurnOff_Win11_Image_Action

		public void Attach_Win11_Image_Action (object sender, EventArgs e) {
			ImageVMMove("Win11");
		} // end Attach_Win11_Image_Action
		//VM Lifecycle
		public void Disgenerate_VM_Image_Action (object sender, EventArgs e) {
			DisgenerateVM(GetSelectedVM());
		} // end Disgenerate_VM_Image_Action

		//Validate Manifest
		public void Validate_Manifest_Action(object sender, EventArgs e) {
			ValidateManifest();
		}// end Validate_Manifest_Action
		
		public void Validate_By_Configure_Action(object sender, EventArgs e) {
			ValidateManifest(0,"","",0,"","","","","",false,false,"","",false, "","Configure");
		}// end Validate_By_ID_Action

		public void Validate_By_ID_Action(object sender, EventArgs e) {
			string PackageIdentifier = inputBox_User.Text;

			ValidateManifest(0,PackageIdentifier,"",0,"","","","","",false,false,"","",false, "--id "+PackageIdentifier);
//ValidateManifest(VM = 0,  PackageIdentifier = "",  PackageVersion = "",  PR = 0,  Arch = "", Scope = "",  InstallerType = "", OS = "", Locale = "", InspectNew = false, notElevated = false, MinimumOSVersion = "",  ManualDependency = "",  NoFiles = false,  installerLine = "",  Operation = "Scan")
		}// end Validate_By_ID_Action

		public void Validate_By_Arch_Action(object sender, EventArgs e) {
			ValidateManifest(0,"","",0,"x64");
			Thread.Sleep(HyperVRateLimitDelay);
			ValidateManifest(0,"","",0,"x86");
		}// end Validate_By_ID_Action

		public void Validate_By_Scope_Action(object sender, EventArgs e) {
			ValidateManifest(0,"","",0,"","Machine");
			Thread.Sleep(HyperVRateLimitDelay);
			ValidateManifest(0,"","",0,"","User");
		}// end Validate_By_ID_Action

		public void Validate_By_Arch_And_Scope_Action(object sender, EventArgs e) {
			ValidateManifest(0,"","",0,"x64","Machine");
			Thread.Sleep(HyperVRateLimitDelay);
			ValidateManifest(0,"","",0,"x86","Machine");
			Thread.Sleep(HyperVRateLimitDelay);
			ValidateManifest(0,"","",0,"x64","User");
			Thread.Sleep(HyperVRateLimitDelay);
			ValidateManifest(0,"","",0,"x86","User");
		}// end Validate_By_ID_Action
		//Generate manifest for selected VM
		public void Manifest_From_Clipboard (object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
		}// end Validate_By_ID_Action

		public void Single_File_Automation_Action(object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
		}// end Validate_By_ID_Action
		//Update manifest
		public void Add_Dependency_Disk_Action (object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
		} // end Add_Dependency_Disk_Action
		
		public void Add_Installer_Switch_Action (object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
		} // end Add_Installer_Switch_Action

		//Modify PR
		public void Add_Waiver_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			dynamic string_out = FromJson(AddWaiver(PR));
			AddPRToRecord(PR,"Waiver");
        }// end Add_Waiver_Action

		public void Label_Action_Action(object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
        }// end Label_Action_Action

		public void Approved_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();

			string Timestamp = DateTime.Now.ToString("H:mm:ss");
			DataRow row = table_val.NewRow();
			row[0] = Timestamp;
			row[1] = PR;
			row[2] =  "";
			row[3] =  "";
			row[4] =  "A";
			row[5] =  0;//M
			row[6] =  "R";
			row[7] =  "G";
			row[8] =  "W";
			row[9] =  "F";
			row[10] =  "I";
			row[11] =  "D";
			row[12] =  "V";
			row[13] =  "";
			row[14] =  "+";
			table_val.Rows.InsertAt(row,0);

			string response_out = FromJson(ApprovePR(PR))["state"];
			table_val.Rows[0].SetField("OK", response_out[0]); 
			AddPRToRecord(PR,"Approved");
        }// end Approved_Action

        public void Needs_Author_Feedback_Action(object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
		}// end Needs_Author_Feedback_Action

        public void Check_Installer_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			CheckInstaller(PR);
        }// end Check_Installer_Action
		//Modify PR - Canned Replies
        public void Automation_Block_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			AddPRToRecord(PR,"Blocking");
			string response_out = ReplyToPR(PR,"AutomationBlock","Network-Blocker");
		}// end Automation_Block_Action

        public void Driver_Install_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			string response_out = ReplyToPR(PR,"DriverInstall","DriverInstall");
			AddPRToRecord(PR,"Blocking");
        }// end Driver_Install_Action
		
        public void Installer_Missing_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			AddPRToRecord(PR,"Feedback");
			string response_out = ReplyToPR(PR,"InstallerMissing",MagicLabels[30]);
        }// end Installer_Missing_Action
		
        public void Installer_Not_Silent_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			AddPRToRecord(PR,"Feedback");
			string response_out = ReplyToPR(PR,"InstallerNotSilent",MagicLabels[30]);
        }// end Installer_Not_Silent_Action
		
        public void Needs_PackageUrl_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			AddPRToRecord(PR,"Feedback");
			string response_out = ReplyToPR(PR,"PackageUrl",MagicLabels[30]);
        }// end Needs_PackageUrl_Action
		
        public void One_Manifest_Per_PR_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			AddPRToRecord(PR,"Feedback");
			string response_out = ReplyToPR(PR,"OneManifestPerPR",MagicLabels[30]);
        }// end One_Manifest_Per_PR_Action
		//Modify PR - Update Manifest
		public void Add_Dependency_Repo_Action (object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
		} // end Add_Dependency_Repo_Action
		
		public void Update_Hash_Action (object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
		} // end Update_Hash_Action
		
		public void Update_Hash2_Action (object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
		} // end Update_Hash2_Action
		
		public void Update_Arch_Action (object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
		} // end Update_Arch_Action
		//Modify PR
        public void Retry_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			dynamic response_out = FromJson(RetryPR(PR));
			AddPRToRecord(PR,"Retry");
		}// end Approved_Action
		
        public void Manually_Validated_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			string response_out = ReplyToPR(PR,"InstallsNormally","","Manually-Validated");
			AddPRToRecord(PR,"Manual");
        }// end Manually_Validated_Action
		//Modify PR - Close PR
        public void Closed_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			string UserInput = inputBox_User.Text;
			inputBox_User.Text = "";
			AddPRToRecord(PR,"Closed");
			InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: "+UserInput+";");
        }// end Closed_Action
		
        public void Merge_Conflicts_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			AddPRToRecord(PR,"Closed");
			dynamic response_out = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: Merge Conflicts;"));
        }// end Merge_Conflicts_Action
		
        public void Version_Already_Exiss_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			AddPRToRecord(PR,"Closed");
			dynamic response_out = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: Version already exists;"));
        }// end Version_Already_Exiss_Action
		
        public void Package_Available_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			AddPRToRecord(PR,"Closed");
			dynamic response_out = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: Package still available;"));
        }// end Package_Available_Action
		
        public void Regen_Hash_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			AddPRToRecord(PR,"Closed");
			dynamic response_out = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: Regenerate with new hash, and the newest version number.;"));
        }// end Package_Available_Action
		
        public void Duplicate_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			int UserInput = Int32.Parse(inputBox_User.Text.Replace("#",""));
			inputBox_User.Text = "";
			AddPRToRecord(PR,"Closed");
			dynamic response_out = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: Duplicate of #"+UserInput+";"));
        }// end Duplicate_Action
		//Modify PR
        public void Project_File_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			AddPRToRecord(PR,"Project");
        }// end Project_File_Action

        public void Squash_Action(object sender, EventArgs e) {
			int PR = GetCurrentPR();
			AddPRToRecord(PR,"Squash");
        }// end Approved_Action

		//Open In Browser
        public void Open_Current_PR_Action(object sender, EventArgs e) {
			OpenPRInBrowser(GetCurrentPR());
			
		}// end Approved_Action

        public void Open_PR_Selected_VM_Action(object sender, EventArgs e) {;
			int PR = Convert.ToInt32(dataGridView_vm.SelectedRows[0].Cells["PR"].Value);
			OpenPRInBrowser(PR);
		}// end Approved_Action
			
        public void Pkgs_Issues_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-pkgs/issues");
        }// end Approval_Search_Action
		
        public void Cli_Issues_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-cli/issues");
        }// end Approval_Search_Action
		
        public void Manual_Merge_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-pkgs/labels/Needs-Manual-Merge");
        }// end Approval_Search_Action
		
        public void Highest_Version_Remaining_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-pkgs/pulls?q=is%3Aopen+is%3Apr+draft%3Afalse+label%3AHighest-Version-Removal+");//HVR
        }// end Approval_Search_Action
		
        public void Approval_Search_Action(object sender, EventArgs e) {
			SearchGitHub("Approval",1,0, false,false,true);
        }// end Approval_Search_Action
		
		public void Defender_Search_Action(object sender, EventArgs e) {
			SearchGitHub("Defender",1,0, false,false,true);
        }// end Defender_Search_Action
		
		public void ToWork_Search_Action(object sender, EventArgs e) {
			SearchGitHub("ToWork",1,0, false,false,true);
        }// end ToWork_Search_Action
		
		public void Open_Repo_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start(GitHubBaseUrl);
		}// end Approved_Action
		//Open In Browser - Open many tabs:
        public void Open_AllUrls_Action(object sender, EventArgs e) {
			string clip = Clipboard.GetText();
			foreach (int PR in PRNumber(clip,true)) {
				OpenPRInBrowser(PR);
				Thread.Sleep(GitHubRateLimitDelay);
			}
		}// end Approved_Action
		
        public void Approval_Run_Search_Action(object sender, EventArgs e) {
			WorkSearch("Approval");
        }// end Approved_Action
		
		public void ToWork_Run_Search_Action(object sender, EventArgs e) {
			WorkSearch("ToWork");
        }// end Approved_Action
		
		public void All_Resources_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start("https://app.gitter.im/#/room/#Microsoft_winget-pkgs:gitter.im");//Gitter chat
			System.Diagnostics.Process.Start("https://dev.azure.com/ms/winget-pkgs/_build");//Pipeline status
			System.Diagnostics.Process.Start("https://stpkgmandashwesus2pme.z5.web.core.windows.net/");//Dashboard
			SearchGitHub("Approval",1,0, false,false,true);//Approval search
			SearchGitHub("ToWork",1,0, false,false,true);//ToWork search
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-pkgs/pulls?q=is%3Aopen+is%3Apr+draft%3Afalse+-label%3ABlocking-Issue++label%3AValidation-Executable-Error+label%3AAzure-Pipeline-Passed+-label%3AValidation-Completed+-label%3AInternal-Error-Dynamic-Scan+-label%3AValidation-Defender-Error+-label%3AChanges-Requested+-label%3ADependencies+-label%3AHardware+-label%3AInternal-Error-Manifest+-label%3AInternal-Error-NoSupportedArchitectures+-label%3ALicense-Blocks-Install+-label%3ANeeds-CLA+-label%3ANetwork-Blocker+-label%3ANo-Recent-Activity+-label%3Aportable-jar+-label%3AReboot+-label%3AScripted-Application+-label%3AWindowsFeatures+-label%3Azip-binary");//APP-VEE
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-pkgs/issues?q=is%3Aopen+assignee%3A"+gitHubUserName+"+-label%3AValidation-Completed+-label%3AValidation-Defender-Error+-label%3AError-Hash-Mismatch");//Assigned to user
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-pkgs/pulls?q=is%3Apr+is%3Aopen+-is%3Adraft+label%3Amoderator-approved+label%3AValidation-Completed+-label%3ANeeds-CLA+-label%3ANeeds-Attention+-label%3ANeeds-Author-Feedback++-label%3ABlocking-Issue+");//Squash-Ready
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-pkgs/labels/Internal-Error-Dynamic-Scan");//IEDS
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-pkgs/pulls?page=1&q=is%3Apr+is%3Aopen+draft%3Afalse+label%3AValidation-Completed+label%3ANeeds-Attention+-label%3ALast-Version-Remaining+-label%3AScripted-Application+-label%3Ahardware");//VCNA
			System.Diagnostics.Process.Start("https://github.com/notifications?query=reason%3Amention");//Notifications mentions
        }// end All_Resources_Action

		public void Start_Of_Day_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-pkgs/issues");
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-cli/issues");
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-pkgs/labels/Needs-Manual-Merge");
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-pkgs/pulls?q=is%3Aopen+is%3Apr+draft%3Afalse+label%3AHighest-Version-Removal+");//HVR
			SearchGitHub("Defender",1,0, false,false,true);
        }// end Start_Of_Day_Action
		//Open In Browser
		public void Open_PKGS_Repo_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start(GitHubBaseUrl);
		}// end Open_PKGS_Repo_Action

		public void Open_CLI_Repo_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start("https://github.com/microsoft/winget-cli/");
        }// end Open_CLI_Repo_Action

		public void Open_Notifications_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start("https://github.com/notifications?query=reason%3Amention");
        }// end Approved_Action

		public void Open_Gitter_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start("https://app.gitter.im/#/room/#Microsoft_winget-pkgs:gitter.im");
        }// end Approved_Action

		public void Open_Pipeline_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start("https://dev.azure.com/ms/winget-pkgs/_build");
        }// end Approved_Action

		public void Open_Dashboard_Action(object sender, EventArgs e) {
			System.Diagnostics.Process.Start("https://stpkgmandashwesus2pme.z5.web.core.windows.net/");
        }// end Approved_Action

		public void Pkgs_Search_Action(object sender, EventArgs e) {
			string UserInput = inputBox_User.Text;
			inputBox_User.Text = "";
			System.Diagnostics.Process.Start("https://github.com/search?q=repo%3Amicrosoft%2Fwinget-pkgs+"+UserInput+"&type=pullrequests");
         }// end Pkgs_Search_Action

		public void Open_SelectedApproved_Action(object sender, EventArgs e) {
			int PR = Convert.ToInt32(dataGridView_val.SelectedRows[0].Cells["PR"].Value);
			OpenPRInBrowser(PR);
        }// end Open_SelectedApproved_Action


		//Help
		public void About_Click_Action (object sender, EventArgs e) {
			string AboutText = "WinGet Approval Pipeline" + Environment.NewLine;
			AboutText += "(c) 2024 Microsoft Corp" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs and request features:" + Environment.NewLine;
			AboutText += "https://Github.com/winget-pkgs/issues/" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			MessageBox.Show(AboutText);
		} // end About_Click_Action

		public void VCDependency_Click_Action (object sender, EventArgs e) {
			string AboutText = "VCRedist DLL to dependency mapping:" + Environment.NewLine;
			AboutText += "Missing DLL - Dependency" + Environment.NewLine;
			AboutText += "MSVCR71.dll - Microsoft.VCRedist.2005.x64 (x86)" + Environment.NewLine;
			AboutText += "MSVCR08.dll - Microsoft.VCRedist.2008.x64 (x86)" + Environment.NewLine;
			AboutText += "MSVCR09.dll & MSVCR100.dll - Microsoft.VCRedist.2010.x64 (x86)" + Environment.NewLine;
			AboutText += "MSVCR120.dll - Microsoft.VCRedist.2012.x64 (x86)" + Environment.NewLine;
			AboutText += "MSVCR130.dll - Microsoft.VCRedist.2013.x64 (x86)" + Environment.NewLine;
			AboutText += "MSVCR140.dll - Microsoft.VCRedist.2015+.x64 (x86)" + Environment.NewLine;
			AboutText += "??? - Microsoft.VCRedist.2019.arm64" + Environment.NewLine;
			AboutText += "??? - Microsoft.VCRedist.2022.arm64" + Environment.NewLine;
			MessageBox.Show(AboutText);
		} // end About_Click_Action





        public void Testing_Action(object sender, EventArgs e) {
			// string string_out = (PRStateFromComments(PR).ToString());
 			// dynamic string_out = GetFileData(DataFileName,"PackageIdentifier", UserInput);
			// dynamic string_out = FromCsv(GetContent(DataFileName)).Where(n => n[Property] != null).Where(n => (string)n[Property].Contains(Match);
			string UserInput = inputBox_User.Text;
			dynamic line = FromCsv(GetContent(DataFileName)).Where(n => (string)n["PackageIdentifier"] == (UserInput));
			outBox_msg.AppendText(Environment.NewLine + "Testing: " + ToJson(line));
		}// end Testing_Action

        public void Testing2_Action(object sender, EventArgs e) {
			string UserInput = inputBox_User.Text;
			List<string> versions = ManifestListing(UserInput);
			// dynamic line = FromCsv(GetContent(DataFileName)).Where(n => (string)n["PackageIdentifier"] == (UserInput));
			outBox_msg.AppendText(Environment.NewLine + "Testing2: " + ToJson(versions));
		}// end Testing_Action





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------   Inject into PRs   --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
/*Inject into PRs
public string AddDependencyToPR(int PR){
	string Dependency = "Microsoft.VCRedist.2015+.x64",
	string SearchString = "Installers:",
	string LineNumbers = CommitFile(PR, string File, string url)   (Select-String SearchString).LineNumber),
	string ReplaceString = "Dependencies:\n  PackageDependencies:\n   - PackageIdentifier: $Dependency\nInstallers:",
	string comment = "\\\\\\suggestion\n$ReplaceString\n\\\\\\\n\n(Automated response - build "build".)"
	string_out = ""
	foreach ($Line in $LineNumbers) {
		string_out += Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Policy "Needs-Author-Feedback"
	}
}
public string UpdateHashInPR(int PR, string ManifestHash, string PackageHash, string LineNumbers = ((Get-CommitFile -PR $PR | Select-String ManifestHash).LineNumber), string ReplaceTerm = ("  InstallerSha256: $($PackageHash.toUpper())"), string comment = "\\\\\\suggestion\n$ReplaceString\n\\\\\\\n\n(Automated response - build "build".)"){
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Policy "Needs-Author-Feedback"
	}
}

public string UpdateHashInPR2(int PR, string clip, string SearchTerm = "Expected hash", string ManifestHash = (YamlValue $SearchTerm -Clip $Clip), string LineNumbers = ((Get-CommitFile -PR $PR | Select-String ManifestHash).LineNumber), string ReplaceTerm = "Actual hash", string PackageHash = ("  InstallerSha256: "+(YamlValue $ReplaceTerm -Clip $Clip).toUpper()), string comment = "\\\\\\suggestion\n$ReplaceString\n\\\\\\\n\n(Automated response - build "build".)"){
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Policy "Needs-Author-Feedback"
	}
}

public string UpdateArchInPR(int PR, string SearchTerm = "  Architecture: x86", string LineNumbers = ((Get-CommitFile -PR $PR | Select-String SearchTerm).LineNumber),string ReplaceTerm = (($SearchTerm.Split(": "))[1]),string ReplaceArch = (("x86","x64").Where(n => n -notmatch $ReplaceTerm}), string ReplaceString = ($SearchTerm.Replace($ReplaceTerm, string ReplaceArch), string comment = "\\\\\\suggestion\n$ReplaceString\n\\\\\\\n\n(Automated response - build "build".)")){
[ValidateSet("x86","x64","arm","arm32","arm64","neutral")]
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Policy "Needs-Author-Feedback"
	}
}
*/		





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------  Inject into Files  --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public void AddToValidationFile(int VM, string Dependency = "Microsoft.VCRedist.2015+.x64"){
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





//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------         Modes       --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
        public void Approving_Action(object sender, EventArgs e) {
			SetMode("Approving");
        }// end Approving_Action
		
        public void IEDS_Action(object sender, EventArgs e) {
			SetMode("IEDS");
        }// end IEDS_Action
		
        public void Validating_Action(object sender, EventArgs e) {
			SetMode("Validating");
        }// end Validating_Action
		
        public void Idle_Action(object sender, EventArgs e) {
			SetMode("Idle");
        }// end Idle_Action







//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------       Misc Data     --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
		public string[] StandardPRComments = {
			"Validation Pipeline Badge",//Pipeline status
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
			"Missing Properties value based on version",//New property detection.
			"Azure Pipelines could not run because the pipeline triggers exclude this branch/path"//Pipeline error.
		};

		public string[] WordFilterList = {
			"accept_gdpr ", 
			"accept-licenses", 
			"accept-license", 
			"eula",
			"downloadarchive.documentfoundation.org",
			"paypal"
		};

		public string[] AppsAndFeaturesEntriesList = {
			"DisplayName", 
			"DisplayVersion", 
			// "Publisher", 
			"ProductCode", 
			"UpgradeCode" //, 
			// "InstallerType"
		};

		public string[] CountrySet = {
			"Default", "Warm", "Cool", "Random", "Afghanistan", "Albania", "Algeria", "American Samoa", "Andorra", "Angola", "Anguilla", "Antigua And Barbuda", "Argentina", "Armenia", "Aruba", "Australia", "Austria", "Azerbaijan", "Bahamas", "Bahrain", "Bangladesh", "Barbados", "Belarus", "Belgium", "Belize", "Benin", "Bermuda", "Bhutan", "Bolivia", "Bosnia And Herzegovina", "Botswana", "Bouvet Island", "Brazil", "Brunei Darussalam", "Bulgaria", "Burkina Faso", "Burundi", "Cabo Verde", "Cambodia", "Cameroon", "Canada", "Central African Republic", "Chad", "Chile", "China", "Colombia", "Comoros", "Cook Islands", "Costa Rica", "Croatia", "Cuba", "Curacao", "Cyprus", "Czechia", "CÃ¶te D'Ivoire", "Democratic Republic Of The Congo", "Denmark", "Djibouti", "Dominica", "Dominican Republic", "Ecuador", "Egypt", "El Salvador", "Equatorial Guinea", "Eritrea", "Estonia", "Eswatini", "Ethiopia", "Fiji", "Finland", "France", "French Polynesia", "Gabon", "Gambia", "Georgia", "Germany", "Ghana", "Greece", "Grenada", "Guatemala", "Guinea", "Guinea-Bissau", "Guyana", "Haiti", "Holy See (Vatican City State)", "Honduras", "Hungary", "Iceland", "India", "Indonesia", "Iran", "Iraq", "Ireland", "Israel", "Italy", "Jamaica", "Japan", "Jordan", "Kazakhstan", "Kenya", "Kiribati", "Kuwait", "Kyrgyzstan", "Laos", "Latvia", "Lebanon", "Lesotho", "Liberia", "Libya", "Liechtenstein", "Lithuania", "Luxembourg", "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali", "Malta", "Marshall Islands", "Mauritania", "Mauritius", "Mexico", "Micronesia", "Moldova", "Monaco", "Mongolia", "Montenegro", "Morocco", "Mozambique", "Myanmar", "Namibia", "Nauru", "Nepal", "Netherlands", "New Zealand", "Nicaragua", "Niger", "Nigeria", "Niue", "Norfolk Island", "North Korea", "North Macedonia", "Norway", "Oman", "Pakistan", "Palau", "Palestine", "Panama", "Papua New Guinea", "Paraguay", "Peru", "Philippines", "Pitcairn Islands", "Poland", "Portugal", "Qatar", "Republic Of The Congo", "Romania", "Russian Federation", "Rwanda", "Saint Kitts And Nevis", "Saint Lucia", "Saint Vincent And The Grenadines", "Samoa", "San Marino", "Sao Tome And Principe", "Saudi Arabia", "Senegal", "Serbia", "Seychelles", "Sierra Leone", "Singapore", "Slovakia", "Slovenia", "Solomon Islands", "Somalia", "South Africa", "South Korea", "South Sudan", "Spain", "Sri Lanka", "Sudan", "Suriname", "Sweden", "Switzerland", "Syrian Arab Republic", "Tajikistan", "Tanzania", " United Republic Of", "Thailand", "Togo", "Tonga", "Trinidad And Tobago", "Tunisia", "Turkey", "Turkmenistan", "Tuvalu", "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom", "United States", "Uruguay", "Uzbekistan", "Vanuatu", "Venezuela", "Vietnam", "Yemen", "Zambia", "Zimbabwe", "Ã…land Islands"
		};

		public string[] MagicStrings = {
			"Installer Verification Analysis Context Information:", //0
			"[error] One or more errors occurred.", //1
			"[error] Manifest Error:", //2
			"BlockingDetectionFound", //3
			"Processing manifest", //4
			"SQL error or missing database", //5
			"Error occurred while downloading installer" //6
		};

		public string[] MagicLabels = {
			"Validation-Defender-Error", //0
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
			
		public string[] HourlyRun_PresetList = {
			"Defender",
			"ToWork2"
		};
    }// end WinGetApprovalPipeline
}// end WinGetApprovalNamespace




//////////////////////////////////////////====================////////////////////////////////////////
//////////////////////====================--------------------====================////////////////////
//===================--------------------      Miscellany     --------------------====================
//////////////////////====================--------------------====================////////////////////
//////////////////////////////////////////====================////////////////////////////////////////
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
|.Timestp..|.PR#.......|.PackageIdentifier......................|.PRVersion........|.A.|.R.|.W.|.F.|.I.|.D.|.V.|.ManifestVer.........|.OK.|..........................................
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
/* A PR's journey through the WinGet pipeline system:
- PR committed - manually or with a tool.
- PR pulled into Automatic Validation Pipeline.
  - On fail, add label.
    - Pipeline errors - these often have the label Internal-Error or Internal-Error-Dynamic-Scan. The former are usually ephemeral and disappear on retry. The latter are sometimes ephemeral, and sometimes happen to a package on every run - it's far enough along that the package can be manually validated. Manual validation might still fail on one of the following errors, and has to manually update labels and comment in the PR similar to how the pipeline would. 
    - PR and Manifest errors - these can often be remediated in PR, then retry and pass.
	- Defender and scan errors - some can linger in the fail-and-remediation state ("Defender Loop") for an extended duration before passing. 
	- Installer and application errors - these can sometimes be remediated in PR, by adding data such as switches or dependencies. If so, retry and pass.
	- Legal and political issues - these can be hard blockers. Some might need the manifest schema to be updated with additional fields, and those fields populated with legal agreements, before the PR can pass. 
	- Unfortunately, for some PRs, the next step is closure. The path to this step isn't always straightforward, and some linger here for an extended duration as well. Closed PRs can be reopened for a good reason. Feel free to ask. 
  - On pass, continue.
- SDL checks occur at some point. These don't take very long, unless you're waiting on the PR.
- PR pends for community and moderator review. (Review "pool")
  - On fail, add comment.
    - Installer: Duplicate PRs, version mismatches between manifest and registry, different installer types.	
    - Locale: Incorrect PackageName, ReleaseNotes not in locale's natural language, PackageUrl not leading to InstallerUrl, and other errata. 
  - On pass, continue.
- PR pends for moderator approval. (Approval pipeline)
  - On fail, add comment.
    - Auth fail - Package has Auth strictness of "must" and submitter isn't on the list. Ask someone who IS on the list for approval. 
	- Version parameter fail - the number of version parameters (data between dots, such as major and minor version numbers) has changed. This is common for some developers, and an exception list is currently manually implemented. 	
	- Version number contains spaces fail - this check needs to be reimplemented. It was meant to catch an automation bug adding spaces after the dots in PackageVersion numbers. 
	- Review fail - PackageIdentifier has review notes blocking approval. Post them.
	- Agreements fail - PackageIdentifier has EULA but PR is missing the AgreementsUrl. Post this.
	- Words filter fail - Manifest contains words (such as "EULA") that are restricted, because they might indicate another check has failed or been skipped. Post about these. 
	- AnF fail - missing the "AppsAndFeaturesEntries" entry but present in previous PR. This check needs to be updated. Usually only block on DisplayVersion, but also note if there are more than 3 of these missing. 
	- InstallerUrl contains PackageVersion - Doesn't block but is informative. Should be rebuilt to include a vanity URL detector, and also detect if the InstallerUrl shows previous version.
	- Files removed - if the PR has more than 2 files, and it's not a removal, check if the previous version had at least as many files. To prevent a PR from leaving out localization files from the previous version. 
	- OR Last Version Remaining fail - If it's a removal, check if it's the highest version. If it is, ask if it's available from another location. 
  - On pass, approve.
- PR pends for publish pipeline.
  - Publish converts repo to an XML database and compresses into MSIX.
  - Uploads to storage location, refreshes CDN. 
- Package is available to users. 
(Goal is to make this have 1 remediation loop instead of 3.)
*/
