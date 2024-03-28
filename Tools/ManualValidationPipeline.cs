//Copyright 2022-2024 Microsoft Corporation
//Author: Stephen Gillie
//Title: WinGet Approval Pipeline v3.-8.0
//Created: 1/19/2024
//Updated: 3/27/2024
//Notes: Tool to streamline evaluating winget-pkgs PRs. 
//Update log:
//3.-8.0 - Port PRWatch.
//3.-9.0 - Port ValidateManifest.
//3.-10.0 - Port ListingDiff.
//3.-11.0 - Port ManifestFile.
//3.-12.0 - Port ManifestAutomation.
//3.-13.0 - Port SingleFileAutomation.
//3.-14.0 - Port ManifestListing.
//3.-15.0 - Port RandomIEDS.
//3.-16.0 - Port main body of ValidateManifest.
//3.-17.2 - Depreciate numerous OPB holdover methods.
//3.-17.1 - Bugfix to VM RAM display.
//3.-17.0 - Create FindWinGetPackage as equivalent. Was scraping Find-WinGetPackage, but that stopped working after the app closed and reopened, so changed to scraping "winget search".






/*Contents:
- Init vars
- Boilerplate
- UI top-of-box
	- Menu
- Tabs
- Automation Tools
- PR tools
- Network tools
- Validation Starts Here
- Manifests Etc
- VM Image Management
- VM Pipeline Management
- VM Status
- VM Versioning
- VM Orchestration
- File Management
- Inject into files on disk
- Inject into PRs
- Reporting
- Clipboard
- Etc
- PR Watcher Utility functions
- Powershell equivalency (+23)
- VM Window management
- Misc data (+5)

Et cetera:
- PR counters on certain buttons - Approval-Ready, ToWork, Defender, IEDS
- VM control buttons

Need work:
CheckStandardPRComments 
AddValidationData
WorkSearch
ListingDiff
ValidateManifest
*/






//Init vars
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
        public int build = 553;//Get-RebuildPipeApp	
		public string appName = "WinGetApprovalPipeline";
		public string appTitle = "WinGet Approval Pipeline - Build ";
		public static string owner = "microsoft";
		public static string repo = "winget-pkgs";

		//public IPAddress ipconfig = (ipconfig);
		//public IPAddress remoteIP = ([ipaddress](($ipconfig[($ipconfig | Select-String "vEthernet").LineNumber..$ipconfig.Length] | Select-String "IPv4 Address") -split ": ")[1]).IPAddressToString
		public static string remoteIP = "";
		public static string RemoteMainFolder = "//"+remoteIP+"/";
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

		//JSON
		JavaScriptSerializer serializer = new JavaScriptSerializer();

		//WMI for VMs
		public ManagementScope scope = new ManagementScope(@"root\virtualization\v2");//, null);
		// Other server's VMs
		// var connectionOptions = new ConnectionOptions(
		// @"en-US",
		// @"domain\user",
		// @"password",
		// null,
		// ImpersonationLevel.Impersonate,
		// AuthenticationLevel.Default,
		// false,
		// null,
		// TimeSpan.FromSeconds(5);
		//public ManagementScope scope = new ManagementScope(new ManagementPath { Server = "hostnameOrIpAddress", NamespacePath = @"root\virtualization\v2" }, connectionOptions);scope.Connect(); 

		//ui
		public RichTextBox outBox = new RichTextBox();
		public RichTextBox outBox_val, outBox_vm;
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

		int DarkMode = 1;//(int)Microsoft.Win32.Registry.GetValue("HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize", "AppsUseLightTheme", -1);
		//0 : dark theme
		//1 : light theme
		//-1 : AppsUseLightTheme could not be found
		
		public Color color_DefaultBack = Color.FromArgb(240,240,240);
		public Color color_DefaultText = Color.FromArgb(0,0,0);
		public Color color_InputBack = Color.FromArgb(255,255,255);
		public Color color_ActiveBack = Color.FromArgb(200,240,240);
		
		int table_vm_Row_Index = 0;

		//Grid
		public static int gridItemWidth = 70;
		public static int gridItemHeight = 45;

		public int lineHeight = 14;
		public int WindowWidth = gridItemWidth*10+20;
		public int WindowHeight = gridItemHeight*12+20;
		
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
		public bool debuggingView = false;






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

			//this.MaximizeBox = false;
			//this.FormBorderStyle = FormBorderStyle.FixedSingle;
			this.Resize += new System.EventHandler(this.OnResize);
			this.AutoScroll = true;
			Icon icon = Icon.ExtractAssociatedIcon("ManualValidationPipeline.ico");
			this.Icon = icon;
			Array.Resize(ref history, history.Length + 2);
			history[historyIndex] = "about:blank";
			historyIndex++;
			
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
	
			// Create the ToolTip and associate with the Form container.
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

		public void drawMenuBar (){
			this.Menu = new MainMenu();
			MenuItem item = new MenuItem("File");
			this.Menu.MenuItems.Add(item);
				item.MenuItems.Add("Specify key file location...", new EventHandler(Save_Key_Click_Action));
				item.MenuItems.Add("Generate Daily Report", new EventHandler(About_Click_Action));

			item = new MenuItem("Modify PR");
			this.Menu.MenuItems.Add(item);
			MenuItem submenu = new MenuItem("Validate PR");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("By ID", new EventHandler(About_Click_Action));
					submenu.MenuItems.Add("By Config", new EventHandler(About_Click_Action));
					submenu.MenuItems.Add("By Arch", new EventHandler(About_Click_Action));
					submenu.MenuItems.Add("By Scope", new EventHandler(About_Click_Action));
					submenu.MenuItems.Add("Both Arch and Scope", new EventHandler(About_Click_Action));
				item.MenuItems.Add("Add Waiver", new EventHandler(Add_Waiver_Action));
				item.MenuItems.Add("Approve PR", new EventHandler(Approved_Action));
				item.MenuItems.Add("Needs Author Feedback (reason)", new EventHandler(About_Click_Action));
				item.MenuItems.Add("Retry PR", new EventHandler(Retry_Action));
				item.MenuItems.Add("Manual Validation complete", new EventHandler(Manually_Validated_Action));
			submenu = new MenuItem("Close PR");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Closed (reason)", new EventHandler(Closed_Action));
					submenu.MenuItems.Add("Merge Conflicts", new EventHandler(Merge_Conflicts_Action));
					submenu.MenuItems.Add("Duplicate (dupe of)", new EventHandler(Duplicate_Action));
				item.MenuItems.Add("Record as Project File", new EventHandler(Project_File_Action));
				item.MenuItems.Add("Squash-Merge", new EventHandler(Squash_Action));

			item = new MenuItem("Update Manifest");
			this.Menu.MenuItems.Add(item);
			submenu = new MenuItem("In Repo");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Add Dependency (VS2015+)", new EventHandler(About_Click_Action));
					submenu.MenuItems.Add("Update Hash", new EventHandler(About_Click_Action));
					submenu.MenuItems.Add("Update Hash2", new EventHandler(About_Click_Action));
					submenu.MenuItems.Add("Update Arch", new EventHandler(About_Click_Action));
			submenu = new MenuItem("On Disk");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Add Dependency (VS2015+)", new EventHandler(About_Click_Action));
					submenu.MenuItems.Add("Add Installer Switch", new EventHandler(About_Click_Action));

			item = new MenuItem("Canned Replies");
			this.Menu.MenuItems.Add(item);
				item.MenuItems.Add("Automation Block", new EventHandler(Automation_Block_Action));
				item.MenuItems.Add("Blocking Issue", new EventHandler(About_Click_Action));
				item.MenuItems.Add("Check Installer", new EventHandler(Check_Installer_Action));
				item.MenuItems.Add("Driver Install", new EventHandler(Driver_Install_Action));
				item.MenuItems.Add("Installer Missing", new EventHandler(Installer_Missing_Action));
				item.MenuItems.Add("Installer Not Silent", new EventHandler(Installer_Not_Silent_Action));
				item.MenuItems.Add("Needs PackageUrl", new EventHandler(Needs_PackageUrl_Action));
				item.MenuItems.Add("One Manifest Per PR", new EventHandler(One_Manifest_Per_PR_Action));
				
			item = new MenuItem("Open In Browser");
			this.Menu.MenuItems.Add(item);
				item.MenuItems.Add("Current PR", new EventHandler(About_Click_Action)); 
				item.MenuItems.Add("Approval Search", new EventHandler(Approval_Search_Action));
				item.MenuItems.Add("ToWork Search", new EventHandler(ToWork_Search_Action)); 
				item.MenuItems.Add("Repo", new EventHandler(About_Click_Action));
				item.MenuItems.Add("Full Approval Run", new EventHandler(Approval_Run_Search_Action));
				item.MenuItems.Add("Full ToWork Run", new EventHandler(ToWork_Run_Search_Action));
				
			item = new MenuItem("VM Lifecycle");
			this.Menu.MenuItems.Add(item);
			submenu = new MenuItem("WIn10 Image VM");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Start", new EventHandler(About_Click_Action)); 
					submenu.MenuItems.Add("Stop", new EventHandler(About_Click_Action)); 
					submenu.MenuItems.Add("Turn Off", new EventHandler(About_Click_Action)); 
					submenu.MenuItems.Add("Attach New VM", new EventHandler(About_Click_Action)); 
			submenu = new MenuItem("Win11 Image VM");
				item.MenuItems.Add(submenu);
					submenu.MenuItems.Add("Start", new EventHandler(About_Click_Action)); 
					submenu.MenuItems.Add("Stop", new EventHandler(About_Click_Action)); 
					submenu.MenuItems.Add("Turn Off", new EventHandler(About_Click_Action)); 
					submenu.MenuItems.Add("Attach New VM", new EventHandler(About_Click_Action)); 
				item.MenuItems.Add("Complete", new EventHandler(Misc_Action));

			item = new MenuItem("Help");
			this.Menu.MenuItems.Add(item);
				item.MenuItems.Add("About", new EventHandler(About_Click_Action));				

			this.BackColor = color_DefaultBack;
			this.ForeColor = color_DefaultText;
			//Preferences
			//Window arrangement
			//Advanced mode (no warnings!)
			//Hourly Run
			//Enable waivers
			//Enable approvals
			//Enable clipboard watching (manifests/)
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
 			
			table_vm.Columns.Add("vm", typeof(string));
			table_vm.Columns.Add("status", typeof(string));
			table_vm.Columns.Add("version", typeof(int));
			table_vm.Columns.Add("OS", typeof(string));
			table_vm.Columns.Add("Package", typeof(string));
			table_vm.Columns.Add("PR", typeof(int));
			table_vm.Columns.Add("RAM", typeof(double));
		
			drawLabel(ref label_VMRAM, col0, row5, gridItemWidth, gridItemHeight,"VM RAM:");
			drawUrlBox(ref inputBox_VMRAM,col1, row5, gridItemWidth*2,gridItemHeight,"");//VM RAM display

			drawLabel(ref label_User, col4, row5, gridItemWidth, gridItemHeight,"User Input:");
			drawUrlBox(ref inputBox_User,col5, row5, gridItemWidth*2,gridItemHeight,"");//UserInput field 

			drawLabel(ref label_PRNumber, col7, row5, gridItemWidth, gridItemHeight,"Current PR:");
			drawUrlBox(ref inputBox_PRNumber,col8, row5, gridItemWidth*2,gridItemHeight,"#000000");
			
			drawOutBox(ref outBox_val, col0, row6, this.ClientRectangle.Width,gridItemHeight*4, "", "outBox_val");

 			drawButton(ref btn10, col0, row10, gridItemWidth, gridItemHeight, "Bulk Approving", Approving_Action);
			drawToolTip(ref toolTip1, ref btn10, "Automatically approve PRs. (Caution - easy to accidentally approve, use with care.)");
			drawButton(ref btn18, col1, row10, gridItemWidth, gridItemHeight, "Individual Validations", Validating_Action);
			drawToolTip(ref toolTip2, ref btn18, "Automatically start manifest in VM.");
 			drawButton(ref btn11, col2, row10, gridItemWidth, gridItemHeight, "Validate Rand IEDS", IEDS_Action);
			drawToolTip(ref toolTip3, ref btn11, "Automatically start manifest for random IEDS in VM.");
			drawButton(ref btn19, col3, row10, gridItemWidth, gridItemHeight, "Idle Mode", Idle_Action);
			drawToolTip(ref toolTip4, ref btn19, "It does nothing.");
			drawButton(ref btn20, col4, row10, gridItemWidth, gridItemHeight, "Config (disabled)", Config_Action);
			
			drawDataGrid(ref dataGridView_vm, col0, row0, gridItemWidth*8, gridItemHeight*5);
			dataGridView_vm.Anchor = AnchorStyles.Top | AnchorStyles.Bottom;

 	 }// end drawGoButton

		public void OnResize(object sender, System.EventArgs e) {
			//VM and Validation windows adjust width with window.
			dataGridView_vm.Width = ClientRectangle.Width;// - gridItemWidth*2;
			outBox_val.Width = ClientRectangle.Width;

			label_User.Left = ClientRectangle.Width/2 - gridItemWidth*2;//col4
			inputBox_User.Left = ClientRectangle.Width/2 - gridItemWidth*1;//col5

			inputBox_PRNumber.Left = ClientRectangle.Width - gridItemWidth*2;//col8
			label_PRNumber.Left = ClientRectangle.Width - gridItemWidth*3;//col7
			// btn13.Left = ClientRectangle.Width - gridItemWidth*1;//col9
			// btn7.Left = ClientRectangle.Width - gridItemWidth*2;//col8
			// btn5.Left = ClientRectangle.Width - gridItemWidth*1;//col9
			// btn3.Left = ClientRectangle.Width - gridItemWidth*2;//col8
			// btn4.Left = ClientRectangle.Width - gridItemWidth*1;//col9
			
			//Validation window adjust height with window.
			outBox_val.Height = ClientRectangle.Height - gridItemHeight*7;
			btn10.Top = ClientRectangle.Height - gridItemHeight;
			btn18.Top = ClientRectangle.Height - gridItemHeight;
			btn11.Top = ClientRectangle.Height - gridItemHeight;
			btn19.Top = ClientRectangle.Height - gridItemHeight;
			btn20.Top = ClientRectangle.Height - gridItemHeight;
			

			//inputBox_PRNumber.Width = ClientRectangle.Width - gridItemWidth*2;
			//btn1.Left = ClientRectangle.Width/4;
		}

		private void timer_Run(object sender, EventArgs e) {
			UpdateTableVM();
			RefreshStatus();
		//Hourly Run functionality
		bool HourLatch = false;
		if (Int32.Parse(DateTime.Now.ToString("mm")) == 20) {
			HourLatch = true;
		}
		if (HourLatch) {
			HourLatch = false;
			Console.Beep(500,250);Console.Beep(500,250);Console.Beep(500,250); //Beep 3x to alert the PC user.
			string[] PresetList = {"Defender","ToWork2"};
			foreach (string Preset in PresetList) {
				dynamic Results = SearchGitHub(Preset,1);
				if (Results != null) {
					//foreach (int Result in Results) {
						// LabelAction(Result);
					//}
				}
			}
			if (Int32.Parse(DateTime.Now.ToString("mm")) == 20) {
				string seconds = DateTime.Now.ToString("ss");
				outBox_val.AppendText(Environment.NewLine + seconds);
				Thread.Sleep((60-Int32.Parse(seconds))*1000);//If it's still :20 after, sleep out the minute. 
			}
		}
			//Update PR display
			string clip = Clipboard.GetText();
			Regex regex = new Regex("^[0-9]{6}$");
			string[] clipSplit = clip.Replace("\r\n","\n").Replace("\n"," ").Replace("/"," ").Replace("#"," ").Split(' ');
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
						outBox_val.AppendText(Environment.NewLine + Mode);
					//ValidateManifest;
					// Mode | clip
				}
			} else if (regex.IsMatch(clip)) {
				Clipboard.SetText("open manifest");	
				outBox_val.AppendText(Environment.NewLine + "> " + clip);
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





//Tabs
	public void PRWatch(bool noNew, string Chromatic = "Default", string LogFile = ".\\PR.txt", string ReviewFile = ".\\Review.csv"){
		string oldclip = "";
		Dictionary<string,dynamic>[] AuthList = GetValidationData("authStrictness");
		Dictionary<string,dynamic>[] AgreementsList = GetValidationData("AgreementUrl");
		Dictionary<string,dynamic>[] ReviewList = FromCsv(GetContent(ReviewFile));
		int Count = 30;
		//$Host.UI.RawUI.WindowTitle = "PR Watcher"//I'm a PR Watcher, watchin PRs go by. 
		SetMode("Approving");
		//Write-Host "| Timestmp | $(Get-PadRight PR// 6) | $(Get-PadRight PackageIdentifier) | $(Get-PadRight PRVersion 15) | A | R | G | W | F | I | D | V | $(Get-PadRight ManifestVer 14) | OK |"
		//Write-Host "| -------- | ----- | ------------------------------- | -------------- | - | - | - | - | - | - | - | - | ------------- | -- |"

		while(Count > 0){
			string clip = Clipboard.GetText();
			string[] split_clip = clip.Split('\n');
			string replace_clip = clip.Replace("'","").Replace("\"","");
			string PRTitle = split_clip.Where(n => regex_hashPRRegexEnd.IsMatch(n)).FirstOrDefault();
			int PR = Int32.Parse(PRTitle.Split('#')[1]);
			if (PRTitle != null) {
				if (PRTitle != oldclip) {
					//(GetStatus() .Where(n => n["status"] == "ValidationCompleted"} | format-Table);//Drops completed VMs in the middle of the PR approval display.
					string validColor = "green";
					string invalidColor = "red";
					string cautionColor = "yellow";
	//Chromatic was here. 

					bool noRecord = false;
					string[] title = PRTitle.Split(':');
					if (title.Length > 1) {
						title = title[1].Split(' ');
					} else {
						title = title[0].Split(' ');
					}
					string Submitter = split_clip.Where(n => n.Contains("wants to merge")).FirstOrDefault().Split(' ')[0];
					string InstallerType = YamlValue("InstallerType",clip);

					//Split the title by spaces. Try extracting the version location as the next item after the word "version", and if that fails, use the 2nd to the last item, then 3rd to last, and 4th to last. for some reason almost everyone puts the version number as the last item, and GitHub appends the PR number.
					int prVerLoc = 0;
					for (int i = 0; i < title.Length; i++) {
						if (title[i].Contains("version")) {
							prVerLoc = i;
						}
					}
					string PRVersion = null;
					//Version is on the line before the line number, and this set indexes with 1 - but the following array indexes with 0, so the value is automatically transformed by the index mismatch.
					try {
						PRVersion = Version.Parse(YamlValue("PackageVersion",replace_clip)).ToString();
					} catch {
						try {
							PRVersion = YamlValue("PackageVersion",replace_clip);
						} catch {
								try {
							PRVersion = Version.Parse(YamlValue("PackageVersion",clip)).ToString();
							} catch {
								if (null != prVerLoc) {
									try {
										PRVersion = Version.Parse(title[prVerLoc]).ToString();
									} catch {
										PRVersion = title[prVerLoc];
									}
								} else {
								//Otherwise we have to go hunting for the version number.
									try {
										PRVersion = Version.Parse(title[-1]).ToString();
									} catch {
										try {
											PRVersion = Version.Parse(title[-2]).ToString();
										} catch {
											try {
												PRVersion = Version.Parse(title[-3]).ToString();
											} catch {
												try {
													PRVersion = Version.Parse(title[-4]).ToString();
												} catch {
													//if it's not a semantic version, guess that it's the 2nd to last, based on the above logic.
													PRVersion = title[-2];
												}
											}
										}
									}; //end try
								}; //end try
							}; //end if null
						}; //end try
					}; //end try

					//Get the PackageIdentifier and alert if it matches the auth list.
					string PackageIdentifier = "";
					try {
						PackageIdentifier = YamlValue("PackageIdentifier",replace_clip);
					} catch {
						PackageIdentifier = replace_clip;
					}
					string matchColor = validColor;





					//Write-Host -nonewline -f $matchColor "| $(Get-Date -format T) | $PR | $(Get-PadRight $PackageIdentifier) | "

					//Variable effervescence
					string prAuth = "+";
					string Auth = "A";
					string Review = "R";
					string WordFilter = "W";
					string AgreementAccept = "G";
					string AnF = "F";
					string InstVer = "I";
					string string_ListingDiff = "D";
					int NumVersions = 99;
					string PRvMan = "P";
					string Approve = "+";

					Dictionary<string,dynamic>[] WinGetOutput = FromCsv(FindWinGetPackage(PackageIdentifier,true));
					string ManifestVersion = WinGetOutput[0]["version"];
					int ManifestVersionParams = ManifestVersion.Split('.').Length;
					int PRVersionParams = PRVersion.Split('.').Length;


					Dictionary<string,dynamic>[] AuthMatch = AuthList .Where(n => n["PackageIdentifier"].Contains(PackageIdentifier)).ToArray();//.Split('.'))[0..1].Join(".")}//Needs matching refactor. #PendingBugfix
					string AuthAccount = "";
					if (AuthMatch != null) {
						AuthAccount = AuthMatch[0]["GitHubUserName"];
					}
					
					if (null == WinGetOutput) {
						PRvMan = "N";
						matchColor = invalidColor;
						Approve = "-!";
						string Body = "";
						if (noNew) {
							noRecord = true;
						} else {
/*
							if ($title[-1] -match $hashPRRegex) {
								if ((Get-Command ValidateManifest).name) {
									ValidateManifest -Silent -InspectNew;
								} else {
									Get-Sandbox ($title[-1] -replace"//","");
								} //end if Get-Command;
							} //end if title;
						} //end if noNew;
					} else if ($null != WinGetOutput) {
						if (PRTitle -match " [.]") {
						//if has spaces (4.4 .5 .220);
							$Body = "Spaces detected in version number.";
							$Body = $Body + "\n\n(Automated response - build $build)";
							InvokeGitHubPRRequest(PR,"Post","comments",Body,"Silent");
							matchColor = invalidColor;;
							$prAuth = "-!";
						}
						if ((ManifestVersionParams != $PRVersionParams) && 
						(PRTitle -notmatch "Automatic deletion") && 
						(PRTitle -notmatch "Delete") && 
						(PRTitle -notmatch "Remove") && 
						($InstallerType -notmatch "portable") && 
						(AuthAccount -cnotmatch $Submitter)) {
*/
							string greaterOrLessThan = "";
							if (PRVersionParams < ManifestVersionParams) {
								//if current manifest has more params (dots) than PR (2.3.4.500 to 2.3.4);
								greaterOrLessThan = "less";
							} else if (PRVersionParams > ManifestVersionParams) {
								//if current manifest has fewer params (dots) than PR (2.14 to 2.14.3.222);
								greaterOrLessThan = "greater";
							}
							matchColor = invalidColor;
							Body = "Hi @"+Submitter+",\\n\\n> This PR's version number "+PRVersion+" has "+PRVersionParams+" parameters (sets of numbers between dots - major, minor, etc), which is "+greaterOrLessThan+" than the current manifest's version "+ManifestVersion+", which has "+ManifestVersionParams+" parameters.\\n\\nDoes this PR's version number **exactly** match the version reported in the \\Apps & features\\ Settings page? (Feel free to attach a screenshot.)";
							Approve = "-!";
							Body = Body + "\\n\\n(Automated response - build "+build+")\\n<!--\\n[Policy] Needs-Author-Feedback\\n[Policy] Version-Parameter-Mismatch\\n-->";
							InvokeGitHubPRRequest(PR,"Post","comments",Body,"Silent");
							AddPRToRecord(PR,"Feedback",PRTitle);
						}
					}
					//Write-Host -nonewline -f matchColor "(Get-PadRight PRVersion.toString() 14) | "
					matchColor = validColor;



					if (AuthMatch != null) {
						string strictness = AuthMatch[0]["authStrictness"].Distinct();
						string matchVar = "";
						matchColor = cautionColor;
						if (AuthAccount == Submitter) {
							matchVar = "matches";
							Auth = "+";
							matchColor = validColor;
						} else {
							matchVar = "does not match";
							Auth = "-";
							matchColor = invalidColor;
						}

						if (strictness == "must") {
							Auth += "!";
						}
					}
					if (Auth == "-!") {
						GetPRApproval(clip,PR,PackageIdentifier);
					}
					//Write-Host -nonewline -f matchColor "Auth | "
					matchColor = validColor;




					
					//Review file only alerts, doesn't block.
					// Dictionary<string,dynamic>[] ReviewMatch = ReviewList.Where(n => n["PackageIdentifier"] == PackageIdentifier);// -match (PackageIdentifier.Split('.'))[0..1].Join(".")}
					// string Review = "";
					// if (ReviewMatch != null) {
						// Review = ReviewMatch.Reason.Distinct();
						// matchColor = cautionColor;
					// }
					//Write-Host -nonewline -f matchColor "Review | "
					matchColor = validColor;



				//In list, matches PR - explicit pass
				//In list, PR has no Installer.yaml - implicit pass
				//In list, missing from PR - block
				//In list, mismatch from PR - block
				//Not in list or PR - pass
				//Not in list, in PR - alert and pass?
				//Check previous version for omission - depend on wingetbot for now.
				string AgreementUrlFromList = AgreementsList.Where(n => n["PackageIdentifier"] == PackageIdentifier).FirstOrDefault()["AgreementUrl"];
				if (AgreementUrlFromList != null) {
					string AgreementUrlFromClip = YamlValue("AgreementUrl",replace_clip);
					if (AgreementUrlFromClip == AgreementUrlFromList) {
						//Explicit Approve - URL is present and matches.
						AgreementAccept = "+!";
					} else {
						//Explicit mismatch - URL is present and does not match, or URL is missing.
						AgreementAccept = "-!";
						ReplyToPR(PR,"AgreementMismatch",AgreementUrlFromList);
					}
				} else {
					AgreementAccept = "+";
					//Implicit Approve - your AgreementsUrl is in another file. Can't modify what isn't there. 
				}
					//Write-Host -nonewline -f matchColor "AgreementAccept | "
					matchColor = validColor;








				if ((!PRTitle.Contains("Automatic deletion")) && 
				(!PRTitle.Contains("Delete")) && 
				(!PRTitle.Contains("Remove")) &&
				(!AgreementAccept.Contains("[+]"))) {

				string[] WordFilterMatch = null;
					foreach (string word in WordFilterList) {
						//WordFilterMatch += Clip.Contains(word) -notmatch "Url" -notmatch "Agreement"
					}

					if (WordFilterMatch != null) {
						WordFilter = "-!";
						Approve = "-!";
						matchColor = invalidColor;
						ReplyToPR(PR,"WordFilter",WordFilterMatch.FirstOrDefault());
					}
				}
					//Write-Host -nonewline -f matchColor "WordFilter | "
					matchColor = validColor;





					

					if (null != WinGetOutput) {
						if ((PRvMan != "N") && 
						(!PRTitle.Contains("Automatic deletion")) && 
						(!PRTitle.Contains("Delete")) && 
						(!PRTitle.Contains("Remove"))) {
							bool ANFOld = ManifestEntryCheck(PackageIdentifier, ManifestVersion);
							bool ANFCurrent = clip.Contains("AppsAndFeaturesEntries");

							if ((ANFOld == true) && (ANFCurrent == false)) {
								matchColor = invalidColor;
								AnF = "-";
								ReplyToPR(PR,"AppsAndFeaturesMissing",Submitter,MagicLabels[30]);
								AddPRToRecord(PR,"Feedback",PRTitle);
							} else if ((ANFOld == false) && (ANFCurrent == true)) {
								matchColor = cautionColor;
								AnF = "-";
								ReplyToPR(PR,"AppsAndFeaturesNew",Submitter,MagicLabels[30]);
								//InvokeGitHubPRRequest(PR,"Post","comments","[Policy] Needs-Author-Feedback","Silent")
							} else if ((ANFOld == false) && (ANFCurrent == false)) {
								AnF = "0";
							} else if ((ANFOld == true) && (ANFCurrent == true)) {
								AnF = "1";
							}
						}
					}
					//Write-Host -nonewline -f matchColor "AnF | "
					matchColor = validColor;





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
										matchColor = invalidColor;
										InstVer = "-";
									}
								}
							}
						} catch {
							matchColor = invalidColor;
							InstVer = "-";
						} //end try
					} //end if PRvMan

					try {
						PRVersion = YamlValue("PackageVersion",clip);
						if (PRVersion.Contains(" ")) {
							matchColor = invalidColor;
							InstVer = "-!";
						}
					}catch{
						//null = (Get-Process) //This section intentionally left blank.
					}

					//Write-Host -nonewline -f matchColor "InstVer | "
					matchColor = validColor;





					if ((PRvMan != "N") && 
					((PRTitle.Contains("Automatic deletion")) || 
					(PRTitle.Contains("Delete")) || 
					(PRTitle.Contains("Remove")))) {//Removal PR
						//Versions = 
						NumVersions = 0;//(WinGetOutput.AvailableVersions).count //Need to rework #PendingBugfix
						if ((PRVersion == ManifestVersion) || (NumVersions == 1)) {
							matchColor = invalidColor;
							ReplyToPR(PR,"VersionCount",Submitter,"[Policy] Needs-Author-Feedback\n[Policy] Last-Version-Remaining");
							AddPRToRecord(PR,"Feedback",PRTitle);
							NumVersions = -1;
						}
					} else {//Addition PR
						string GLD = "";//ListingDiff(clip .Where(n => n.SideIndicator == "<=")).installer.yaml //Ignores when a PR adds files that didn't exist before.
						if (null != GLD) {
							if (GLD == "Error") {
								string_ListingDiff = "E";
								matchColor = invalidColor;
							} else {
								string_ListingDiff = "-!";
								matchColor = cautionColor;
								ReplyToPR(PR,"ListingDiff",GLD);
								InvokeGitHubPRRequest(PR,"Post","comments","[Policy] Needs-Author-Feedback","Silent");
								AddPRToRecord(PR,"Feedback",PRTitle);
							}//end if GLD
						}//end if null
					}//end if PRvMan
					//Write-Host -nonewline -f $matchColor "$ListingDiff | "
					//Write-Host -nonewline -f $matchColor "$NumVersions | "
					matchColor = validColor;





					if (PRvMan != "N") {
						if (null == PRVersion || "" == PRVersion) {
							noRecord = true;
							PRvMan = "Error:PRVersion";
							matchColor = invalidColor;
						} else if (ManifestVersion == "Unknown") {
							noRecord = true;
							PRvMan = "Error:ManifestVersion";
							matchColor = invalidColor;
						} else if (ManifestVersion == null) {
							noRecord = true;
							PRvMan = "Error:ManifestVersion";//WinGetOutput;
							matchColor = invalidColor;
						} else if (Version.Parse(PRVersion) > Version.Parse(ManifestVersion)) {
							PRvMan = ManifestVersion;
						} else if (Version.Parse(PRVersion) < Version.Parse(ManifestVersion)) {
							PRvMan = ManifestVersion;
							matchColor = cautionColor;
						} else if (Version.Parse(PRVersion) == Version.Parse(ManifestVersion)) {
							PRvMan = "=";
						} else {
							noRecord = true;
							PRvMan = "Error:ManifestVersion";//WinGetOutput;
						}
					}


					if ((Approve == "-!") || 
					(Auth == "-!") || 
					(AnF == "-") || 
					(InstVer == "-!") || 
					(prAuth == "-!") || 
					(string_ListingDiff == "-!") || 
					(NumVersions == 1) || 
					(NumVersions == -1) || 
					(WordFilter == "-!") || 
					(AgreementAccept == "-!") || 
					(PRvMan == "N")) {
					//|| (PRvMan -match "^Error")
						matchColor = cautionColor;
						Approve = "-!";
						noRecord = true;
					}

					PRvMan = PadRight(PRvMan,14);
					//Write-Host -nonewline -f matchColor "PRvMan | "
					matchColor = validColor;





					if (Approve == "+") {
						ApprovePR(PR);
						AddPRToRecord(PR,"Approved",PRTitle);
					}

					//Write-Host -nonewline -f $matchColor "$Approve | "
					//Write-Host -f $matchColor ""

					oldclip = PRTitle;
				} //end if PRTitle
			} //end if PRTitle
			Thread.Sleep(1000);
		} //end while Count
		Count--;
	} //end function

		public void WorkSearch(string Preset, int Days = 7) {
		// string[] PresetList = {"Approval","ToWork"};
			// foreach (string Preset in PresetList) {
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
						//This part is too spammy, checking Last-Version-Remaining on every run (sometimes twice a day) for a week as the PR sits. 
						// if((FullPR["title"].Contains("Remove")) || 
						// (FullPR["title"].Contains("Delete")) || 
						// (FullPR["title"].Contains("Automatic deletion"))){
							// Get-GitHubPreset CheckInstaller -PR $PR
						// }
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
			// }//end foreach Preset
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

									string PRTitle = FromJson(InvokeGitHubPRRequest(PR,""))["title"];
									if ((PRTitle.Contains("Automatic deletion")) || (PRTitle.Contains("Remove"))) {
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
							string PRTitle = FromJson(InvokeGitHubPRRequest(PR,""))["title"];
							foreach (Dictionary<string,object> Waiver in GetValidationData("autoWaiverLabel")) {
								if (PRTitle.Contains((string)Waiver["PackageIdentifier"])) {
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
			//StopProcess("photosapp");
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

		public string RetryPR(int PR) {
			AddPRToRecord(PR,"Retry");
			return InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","@wingetbot run");
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

		public string PRInstallerStatusInnerWrapper (string Url){
			//This was a hack to get around Invoke-WebRequest hard blocking on failure, where this needed to be captured and transmitted to a PR comment. And so might not be needed here.
			return InvokeWebRequest(Url, "Head");//.StatusCode;
		}






//Validation Starts Here
public void ValidateManifest(int VM = 0, string PackageIdentifier = "", string PackageVersion = "", int PR = 0, string Arch = "",string Scope = "", string InstallerType = "",string OS = "",string Locale = "",bool InspectNew = false,bool notElevated = false,string MinimumOSVersion = "", string ManualDependency = "", bool NoFiles = false, string Operation = "Scan"){
		if (VM == 0) {
			VM = NextFreeVM(OS);//.Replace("vm","");
		}

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
		
		//[ValidateSet("Win10","Win11")]
		//[ValidateSet("Configure","DevHomeConfig","Pin","Scan")]
		int lowerIndex = clipInput.IndexOf("Do not share my personal information") -1;//This is the last visible string at the bottom of the Files page on GitHub. 
		
		string clip = clipInput.Substring(0,lowerIndex);
		if (PackageIdentifier == "") {
			PackageIdentifier = YamlValue("PackageIdentifier",clip).Replace("\"","").Replace("'","");
		}
		if (PackageVersion == "") {
			PackageVersion = YamlValue("PackageVersion",clip).Replace("\"","").Replace("'","");
		}
		if (PR == 0) {
			PR = PRNumber(clip,true).FirstOrDefault();
		}
		string RemoteFolder = "//"+remoteIP+"/ManVal/vm/"+VM.ToString();
		string installerLine = "--manifest "+RemoteFolder+"/manifest";
		string optionsLine = "";

	/*Sections:
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
	
	TestAdmin();
	if (VM == 0){
		//Write-Host "No available OS VMs";
		GenerateVM(OS);
		//break;
		}
	SetStatus(VM, "Prevalidation", PackageIdentifier,PR);
	//($g.Properties | where {$_.name -eq "EnabledState"}).value != 2;
	// if ((Get-VM "vm"+VM).state != "Running") {
		SetVMState("vm"+VM, 2);
	// };// }

		string logLine = OS.ToString();
		string nonElevatedShell = "";
		string logExt = "log";
		string VMFolder = MainFolder+"\\vm\\"+VM;
		string manifestFolder = VMFolder+"\\manifest";
		string CmdsFileName = VMFolder+"\\cmds.ps1";

	if (Operation == "Configure") {
			//Write-Host "Running Manual Config build $build on vmVM for ConfigureFile"
		string wingetArgs = "configure -f "+RemoteFolder+"/manifest/config.yaml --accept-configuration-agreements --disable-interactivity";
		Operation = "Configure";
		InspectNew = false;
	} else {
		if (PackageIdentifier == "") {
			//Write-Host "Bad PackageIdentifier: $PackageIdentifier"
			//Break;
			Clipboard.SetText(PackageIdentifier);
		}
			//Write-Host "Running Manual Validation build $build on vmVM for package $PackageIdentifier version $PackageVersion"
		
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

		string archDetect = "";
		string archColor = "yellow";
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
		string MDLog = "";
		if (ManualDependency != "") {
			MDLog = ManualDependency;
				//Write-Host " = = = = Installing manual dependency $ManualDependency = = = = "
			ManualDependency = "Out-Log 'Installing manual dependency "+MDLog+".';Start-Process 'winget' 'install "+MDLog+" --accept-package-agreements --ignore-local-archive-malware-scan' -wait\n";
		}
		if (notElevated  == true || clip.Contains("ElevationRequirement: elevationProhibited")) {
				//Write-Host " = = = = Detecting de-elevation requirement = = = = "
			nonElevatedShell = "if ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')){& explorer.exe 'C:\\Program Files\\PowerShell\\7\\pwsh.exe';Stop-Process (Get-Process WindowsTerminal).id}";
			//if elevated, run^^ and exit, else run cmds.
		}
		string packageName = (PackageIdentifier.Split('.'))[1];
		string wingetArgs = "install "+optionsLine+" "+installerLine+" --accept-package-agreements --ignore-local-archive-malware-scan";
	}
	string[] cmdsOut = null;





























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
			string[] Files = null;
			Files[0] = "Package.installer.yaml";
			string[] FileNames = clip.Split(' ').Where(n => n.Contains("[.]yaml")).ToArray();
			for (int i = 0;i < FileNames.Length; i++){
				string[] array_path = FileNames[i].Split('/');
				FileNames[i] = (array_path)[array_path.Length];
			}
			string replace = FileNames[FileNames.Length].Replace(".yaml","");
			for (int i = 0;i < FileNames.Length; i++){
				Files[i] = FileNames[i].Replace(replace,"Package");
			}
			string[] split_clip = clip.Replace("@@","∞").Split('∞');
			for (int i=0;i < Files.Length;i++) {
				string File = Files[i];
				string[] inputObj = split_clip[i*2].Split('\n');
				
				//[1..((inputObj| Select-String "ManifestVersion" -SimpleMatch).LineNumber -1)] 
				//inputObj = inputObj.Where(n => n -notmatch "marked this conversation as resolved."}
				//#PendingBugfix
				FilePath = manifestFolder+"\\"+File;
					//Write-Host "Writing $($inputObj.Length) lines to $FilePath"
				OutFile(FilePath,inputObj);
				//Bugfix to catch package identifier appended to last line of last file.
				// string fileContents = GetContent(FilePath);
				string[] fileContents = GetContent(FilePath).Split('\n');
				if (fileContents[fileContents.Length].Contains(PackageIdentifier)) {
					fileContents[fileContents.Length] = (fileContents[fileContents.Length].Replace("PackageIdentifier","∞").Split('∞'))[0];
				}
				string out_file = string.Join("\n",fileContents);
				out_file.Replace("0New version: ","0").Replace("0New package: ","0").Replace("0Add version: ","0").Replace("0Add package: ","0").Replace("0Add ","0").Replace("0New ","0").Replace("0package: ","0");
				OutFile(FilePath,out_file);
			}
			string[] entries = Directory.GetFileSystemEntries(manifestFolder, "*", SearchOption.AllDirectories);
			int filecount = entries.Length;
			string filedir = "ok";
			string filecolor = "green";
			if (filecount < 3) { filedir = "too low"; filecolor = "red";}
			if (filecount > 3) { filedir = "high"; filecolor = "yellow";}
			if (filecount > 10) { filedir = "too high"; filecolor = "red";}
				//Write-Host -f $filecolor "File count $filecount is $filedir"
			// if (filecount < 3) { break;}
			string[] fileContents2 = GetContent(runPath+"\\"+VM+"\\manifest\\Package.yaml").Split('\n');
			if (fileContents2[fileContents2.Length] != "0") {
				//#PendingBugfix - Needs refactor - this is supposed to cut everything after the last 0 in the ManifestVersion, but this isn't always the last line. 
				fileContents2[fileContents2.Length] = fileContents2[fileContents2.Length].Replace(".0","∞").Split('∞')[0]+".0";
				OutFile(FilePath,fileContents2);
			}//end if fileContents2		
		}//end if Configure
	}//end if NoFiles

	if (InspectNew = true) {
		Dictionary<string,dynamic>[] PackageResult = FromCsv(FindWinGetPackage(PackageIdentifier,true));
			//Write-Host "Searching Winget for PackageIdentifier"
		//Write-Host PackageResult
		if (PackageResult == null) {//"No package found matching input criteria."
			OpenAllURLs(clip);
			System.Diagnostics.Process.Start("https://www.bing.com/search?q="+PackageIdentifier);
			string a = PackageIdentifier.Split('.')[0];
			string b = PackageIdentifier.Split('.')[1];
			if (a != "") {
					//Write-Host "Searching Winget for a"
					//Dictionary<string,dynamic>[] result_a = FromCsv(FindWinGetPackage(a,true));
					//Need to refactor these - they're meant to dump into console. 
			}
			if (b != "") {
					//Write-Host "Searching Winget for b"
					//Dictionary<string,dynamic>[] result_b = FromCsv(FindWinGetPackage(b,true));
			}
		}//end if PackageResult
	}//end if InspectNew
		//Write-Host "File operations complete, starting VM operations."
	RevertVM(VM);
	LaunchWindow(VM);
}//end manifest




//Manifests Etc - Section needs refactor badly
		public void SingleFileAutomation(int PR) {
			string clip = Clipboard.GetText();
			string PackageIdentifier = YamlValue("PackageIdentifier",clip);
			string version = YamlValue("PackageVersion",clip).Replace("'","").Replace("\"","");
			string[] listing = ManifestListing(PackageIdentifier);
			int VM = ManifestFile(PR);
			
			for (int file = 0; file < listing.Length;file++) {
				clip = FileFromGitHub(PackageIdentifier,version,listing[file]);
				ManifestFile(PR, "", "", "", VM,clip);
			}
		}

		public void ManifestAutomation(int VM = 0, int	 PR =0, string Arch = "", string OS = "", string Scope = ""){
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

		public int ManifestFile(int PR = 0, string Arch = "", string OS = "", string Scope = "", int VM = 0, string clip = ""){
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

		public string[] ManifestListing(string PackageIdentifier,bool Versions = false){
			string FirstLetter = PackageIdentifier.ToLower()[0].ToString();
			string Path = PackageIdentifier.Replace(".","/");
			string Version = FromCsv(FindWinGetPackage(PackageIdentifier,true))[0]["version"];
			string Uri = GitHubApiBaseUrl+"/contents/manifests/"+FirstLetter+"/"+Path+"/"+Version+"/";
			if (Versions) {
				Uri = GitHubApiBaseUrl+"/contents/manifests/"+FirstLetter+"/"+Path+"/";
			}
			string[] string_out = null;
			try{
				string_out = FromJson(InvokeGitHubRequest(Uri))["name"];
			} catch {
				string_out[0] = "Error";
			}
			string_out = string.Join("\n",string_out).Replace(PackageIdentifier+".","").Split('\n');
			return string_out;
		}

		public string ListingDiff(string string_PRManifest){
			string PackageIdentifier = YamlValue("PackageIdentifier", string_PRManifest.Replace("\"",""));

			//Get the lines from the PR manifest containing the filenames.
			string[] split_PRManifest = string_PRManifest.Split('\n')
			.Where(n => n.Contains(".yaml"))
			.Where(n => n.Contains(PackageIdentifier)).ToArray();
			//Go through these and snip the PackageIdentifier.
			for (int i = 0; i < split_PRManifest.Length; i++) {
				string[] mid_array = split_PRManifest[i].Replace(PackageIdentifier+".", "").Split('/');
				split_PRManifest[i] = split_PRManifest[i].Replace(PackageIdentifier+".", "").Split('/')[mid_array.Length];
			}

			string returnables = "";
			if (split_PRManifest.Length > 2){//If there are more than 2 files, so a full multi-part manifest and not just updating ReleaseNotes or ReleaseDate, etc. The other checks for this logic (not deletion PR,etc) are in the main Approval Watch method, so maybe this should join them.
				string CurrentManifest = string.Join("\n",ManifestListing(PackageIdentifier));
				//Gather the lines from the newest manifest in repo. Counterpart to the above section.
				if (CurrentManifest == "Error") {
					//If CurrentManifest didn't get any results, (no newest manifest = New package) compare that error with the file list in the PR. 
					//returnables = diff CurrentManifest split_PRManifest;
					//Need to rebuild in absence of Compare-Object.
				} else {
					//But if CurrentManifest did return something, return that. 
					returnables = CurrentManifest;
				}
			}
			return returnables;
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






//VM Image Management
		public void ImageVMStart(string OS = "Win10"){
		//[ValidateSet("Win10","Win11")]
			TestAdmin();
			int VM = 0;
			SetVMState(OS, 2);// ;
			RevertVM(VM);//,OS
			LaunchWindow(VM);//,OS
		}

		public void ImageVMStop(string OS = "Win10"){
			//[ValidateSet("Win10","Win11")]
			TestAdmin();
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
			RedoCheckpoint(VM,OS);
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
			TestAdmin();
			if (OS == "Win10") {
				CurrentVMName = "Windows 10 MSIX packaging environment";
			} else if (OS == "Win11") {
				CurrentVMName = "Windows 11 dev environment";
			}
			//ManagementObject VM = GetVM(CurrentVMName);
			MoveVMStorage(CurrentVMName,newLoc);
			RenameVM(CurrentVMName,OS); 
		}






//VM Pipeline Management
		public void GenerateVM(string OS = "Win10"){
			int vm = GetContent(vmCounter)[0];
			int version = GetVMVersion(OS);
			string destinationPath = imagesFolder+"\\" + vm + "\\";
			string VMFolder = MainFolder + "\\vm\\" + vm;
			string newVmName = "vm" + vm;
			//string startTime = (Get-Date)
			TestAdmin();
			//Write-Host "Creating VM $newVmName version $version OS OS"
			OutFile(vmCounter,vm+1);
			OutFile(StatusFile,"\"VM\",\"Generating\",\"$version\",\"OS\",\"\",\"1\",\"0\"",true);
			RemoveItem(destinationPath,true);
			RemoveItem(VMFolder,true);
			string path = imagesFolder+"\\OS-image\\Virtual Machines\\";
			string VMImageFolder = Directory.GetFileSystemEntries(path, "*.vmcx", SearchOption.AllDirectories)[0];

			//Write-Host "Takes about 120 seconds..."
			ImportVM(VMImageFolder, destinationPath);
			RenameVM(vm.ToString(),newVmName); //(Get-VM | Where-Object {($_.CheckpointFileLocation)+"\\" == $destinationPath}) newName $
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
			
			TestAdmin();
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

		public void RevertVM(int vm){
			TestAdmin();
			string VMName = "vm"+vm;
			SetStatus(vm,"Restoring") ;
			RestoreVMSnapshot(VMName);
		}

		public void CompleteVM(int vm){
			string VMFolder = MainFolder+"\\vm\\"+vm;
			string filesFileName = VMFolder+"\\files.txt";
			string VMName = "vm"+vm;
			TestAdmin();
			SetStatus(vm,"Completing");
			var processes = Process.GetProcessesByName("vmconnect");
			foreach (Process process in processes){
				if (process.MainWindowTitle ==(VMName)) {
				process.CloseMainWindow();
				}
			}
			SetVMState("vm"+vm, 4);
			RemoveItem(filesFileName);
			SetStatus(vm,"Ready");
		}

		public void StopVM(int vm,string VMName = ""){
			if (VMName == "") {
				VMName = "vm"+vm;
			}
			TestAdmin();
			SetVMState(VMName, 3);
		}






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

		public void RefreshStatus() {
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
				double VMRAM = 0;
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
					dynamic Status = FromCsv(GetContent(StatusFile));
					if (Status != null) {
						for (int r = 1; r < Status.Length -1; r++){
							var rowData = Status[r];//Reload the table
							table_vm.Rows.Add(rowData["vm"], rowData["status"], rowData["version"], rowData["OS"], rowData["Package"], rowData["PR"], rowData["RAM"]);
						}//end for r
					}//end if Status
					dataGridView_vm.DataSource=table_vm;
					dataGridView_vm.Rows[table_vm_Row_Index].Selected = true;//Reselect the row.
				}//end if TestPath
			} catch (Exception e){
				outBox_val.AppendText(Environment.NewLine + "e: "+e);//Complain about your failures in the console proxy.
			}//end try 
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

		public void RedoCheckpoint(int vm,string VMName = ""){
			if (VMName == "") {
				VMName = "vm"+vm;
			}
			TestAdmin();
			SetStatus(vm,"Checkpointing");
			RemoveVMSnapshot(VMName);
			CheckpointVM(VMName);
			SetStatus(vm,"Complete");
		}






		//File Management
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


				OutFile(DataFileName, ToCsv(data));
		}






//PR Watcher Utility functions
		public void Sandbox(string string_PRNumber){
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
		
		Checkpoint-VM = Checkoint-VM
		Remove-VMSnapshot = RemoveVMSnapshot
		Restore-VMSnapshot = RestoreVMSnapshot
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
				Text += e.Message + Environment.NewLine;
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
		//Hyper-V
		public ManagementObject GetVM(string VMName) {
			return GetCimService("Msvm_ComputerSystem WHERE ElementName = '" + VMName + "'");
		}
		/*States: 
		1: Other
		2: Start-VM
		3: Stop-VM -TurnOff
		4: Stop-VM
		5: ???
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
            foreach (ManagementObject setting in settings)
            {
                //Console.WriteLine(setting.Path.Path);
                //Console.WriteLine(setting["ElementName"]);
                virtualSystemsetting = setting;
            }
            return virtualSystemsetting;
        }

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

		public uint RestoreVMSnapshot(string VMName) {
			ManagementObject snapshot = GetLastSnapshot(VMName);
			ManagementObject snapshotService = GetCimService("Msvm_VirtualSystemSnapshotService");

			var inParameters = snapshotService.GetMethodParameters("ApplySnapshot");
			inParameters["Snapshot"] = snapshot.Path.Path;
			var outParameters = snapshotService.InvokeMethod("ApplySnapshot", inParameters, null);
			return (uint)outParameters["ReturnValue"];
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
		
		public void RenameVM(string CurrentName, string NewName) {
			Process process = new Process();
			string command = "Rename-VM -VM "+CurrentName+" -newName "+NewName;
			process.StartInfo.Arguments = string.Format(command);
			process.StartInfo.FileName = "PowerShell.EXE";
			process.StartInfo.CreateNoWindow = true;
			process.StartInfo.UseShellExecute = false;
			process.Start();
			process.WaitForExit(); 
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
			process.StartInfo.Arguments = string.Format(command);
			process.StartInfo.FileName = "PowerShell.EXE";
			process.StartInfo.CreateNoWindow = true;
			process.StartInfo.UseShellExecute = false;
			process.Start();
			process.WaitForExit(); 
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

		public void  WindowLoc (int vm,ref RECT rect) {
			//Need to readd the logic that finds the mainwindowhandle from the VM number.
			var processes = Process.GetProcessesByName("vmconnect");
			string VMName = "vm"+vm;
			foreach (Process process in processes){
				if (process.MainWindowTitle ==(VMName)) {
					GetWindowRect(process.MainWindowHandle,out rect);
				}
			}
		}

		public void  WindowSet (int vm,int Left,int Top,int Right,int Bottom) {
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






//Connective functions
		//Searches
		public void ToWork_Search_Action(object sender, EventArgs e) {
			SearchGitHub("ToWork",1,0, false,false,true);
        }// end Approved_Action
		
        public void Approval_Search_Action(object sender, EventArgs e) {
			SearchGitHub("Approval",1,0, false,false,true);
        }// end Approved_Action
		
        public void Add_Waiver_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			dynamic string_out = FromJson(AddWaiver(PR));
			outBox_val.AppendText(Environment.NewLine + "Waiver: "+PR + " "+ string_out["body"]);
			//outBox_val.AppendText(Environment.NewLine + CannedMessage("AutoValEnd","testing testing 1..2..3."));
        }// end Approved_Action
		
		public void ToWork_Run_Search_Action(object sender, EventArgs e) {
			WorkSearch("ToWork");
        }// end Approved_Action
		
        public void Approval_Run_Search_Action(object sender, EventArgs e) {
			WorkSearch("Approval");
        }// end Approved_Action
		//Close PR
        public void Closed_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string UserInput = inputBox_User.Text;
			inputBox_User.Text = "";
			AddPRToRecord(PR,"Closed");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			dynamic response_out = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: "+UserInput+";"));
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out["body"]);
        }// end Closed_Action
		
        public void Duplicate_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			int UserInput = Int32.Parse(inputBox_User.Text.Replace("#",""));
			inputBox_User.Text = "";
			AddPRToRecord(PR,"Closed");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			dynamic response_out = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: Duplicate of #"+UserInput+";"));
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out["body"]);
        }// end Duplicate_Action
		
        public void Merge_Conflicts_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Closed");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			dynamic response_out = FromJson(InvokeGitHubPRRequest(PR,WebRequestMethods.Http.Post,"comments","Close with reason: Merge Conflicts;"));
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out["body"]);
        }// end Merge_Conflicts_Action
		//Canned Replies
        public void Automation_Block_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Blocking");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string response_out = ReplyToPR(PR,"AutomationBlock","Network-Blocker");
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
		}// end Automation_Block_Action

        public void Driver_Install_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string response_out = ReplyToPR(PR,"DriverInstall","DriverInstall");
			AddPRToRecord(PR,"Blocking");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Driver_Install_Action
		
        public void Installer_Missing_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Feedback");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string response_out = ReplyToPR(PR,"InstallerMissing",MagicLabels[30]);
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Installer_Missing_Action
		
        public void Installer_Not_Silent_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Feedback");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string response_out = ReplyToPR(PR,"InstallerNotSilent",MagicLabels[30]);
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Installer_Not_Silent_Action
		
        public void Needs_PackageUrl_Action(object sender, EventArgs e) {
			//outBox_val.AppendText(Environment.NewLine + SearchGitHub("Approval")[0]["number"]);
			Process[] processes = Process.GetProcesses(); 
			outBox_val.AppendText(Environment.NewLine + processes[0]);
        }// end Needs_PackageUrl_Action
		
        public void One_Manifest_Per_PR_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Feedback");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			string response_out = ReplyToPR(PR,"OneManifestPerPR",MagicLabels[30]);
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end One_Manifest_Per_PR_Action
				//Misc
        public void Check_Installer_Action(object sender, EventArgs e) {
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
        }// end Check_Installer_Action
		
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
		//File
		public void Save_Key_Click_Action(object sender, EventArgs e) {
			// save
					MessageBox.Show("You're saved");
		}// end Save_Key_Click_Action
		//Reporting
        public void Approved_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			dynamic response_out = FromJson(ApprovePR(PR));
			AddPRToRecord(PR,"Approved");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out["state"]);
        }// end Approved_Action
		
        public void Manually_Validated_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string response_out = ReplyToPR(PR,"InstallsNormally","Manually-Validated");
			AddPRToRecord(PR,"Manual");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Manually_Validated_Action

        public void Project_File_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Project");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + "Project");
        }// end Project_File_Action

        public void Retry_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			string response_out = RetryPR(PR);
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
			}// end Approved_Action

        public void Misc_Action(object sender, EventArgs e) {
			//int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			//string response_out = ToJson(GetVM("vm679"));
			string hostName = Dns.GetHostName();
			string IP = Dns.GetHostEntry(hostName).AddressList[4].ToString();   
			outBox_val.AppendText(Environment.NewLine + "IP: " + IP);
			}// end Approved_Action

        public void Squash_Action(object sender, EventArgs e) {
			int PR = Int32.Parse(inputBox_PRNumber.Text.Replace("#",""));
			AddPRToRecord(PR,"Squash");//[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
			outBox_val.AppendText(Environment.NewLine + "PR "+ PR + ": " + "Squash");
        }// end Approved_Action
//Inject into files on disk
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






		//Modes
        public void Approving_Action(object sender, EventArgs e) {
			string Status = "Approving";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			//outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Approving_Action
		
        public void IEDS_Action(object sender, EventArgs e) {
			string Status = "IEDS";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			//outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end IEDS_Action
		
        public void Validating_Action(object sender, EventArgs e) {
			string Status = "Validating";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			//outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Validating_Action
		
        public void Idle_Action(object sender, EventArgs e) {
			string Status = "Idle";
			SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			//outBox_val.AppendText(Environment.NewLine + "Status: "+Status);
        }// end Idle_Action

        public void Config_Action(object sender, EventArgs e) {
			//var vm = GetVM("vm674");
            //ManagementObject snapshotSettingData = GetLastVirtualSystemSnapshot(vm);

			//string Status = "Idle";
			//SetMode(Status);//[ValidateSet("Approving","Idle","IEDS","Validating")]
			string mid_string = FindWinGetPackage(inputBox_User.Text);
			Dictionary<string,dynamic>[] FindPkg = FromCsv(mid_string);
			//outBox_val.AppendText(Environment.NewLine + "mid_string: " + mid_string);
			
			foreach (Dictionary<string,dynamic> package in FindPkg) {
				if (package != null) {
					try {
						// outBox_val.AppendText(Environment.NewLine + "ToJson: " + ToJson(package));
						outBox_val.AppendText(Environment.NewLine + "ID: " + package["Id"]+ " - Version: " + package["Version"]);
					} catch (Exception err) {
						// outBox_val.AppendText(Environment.NewLine + "err2: " + err);
					}
				} else {
					//outBox_val.AppendText(Environment.NewLine + "null: " );
				}
			}
						
        }// end Config_Action

		public string FindWinGetPackage(string PackageIdentifier,bool Equals = false) {

			string string_out = "";	
			string command = "winget search " + PackageIdentifier;
			if (Equals == true) {
				//command += " -MatchOption Equals";
			}

			Process process = new Process();
			StreamWriter StandardInput;
			StreamReader StandardOut;
			//StreamReader StandardErr;
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
			string[] strung_out = string_out
			.Replace("'\r\n","\n")
			.Replace("   - ","\n")
			.Replace("   \\ ","\n")
			.Replace("                                                                                                                        ","\n")
			.Split('\n').Where(n => !n.Contains("PS C:\\"))
			.Where(n => !n.Contains("Windows PowerShell"))
			.Where(n => !n.Contains("Copyright (C) Microsoft Corporation"))
			.Where(n => !n.Contains("Install the latest PowerShell"))
			.Where(n => !n.Contains("----"))
			.Where(n => n.Length > 1).ToArray();
			//outBox_val.AppendText();
			string nope = Environment.NewLine + "strung_out" +string.Join("\n",strung_out);
				
			int stringStart = string_out.IndexOf("Name");
			int stringLength = string_out.IndexOf("Source") - string_out.IndexOf("Name");
			
			//string headerRow = strung_out.SubstringWhere(n => n.Contains("Source")).FirstOrDefault();
			string headerRow = string_out.Substring(stringStart, stringLength+6);
			// outBox_val.AppendText(Environment.NewLine + "headerRow: "+ headerRow);
			int firstColumnStart = 0;
			int secondColumnStart = 0;
			int thirdColumnStart = 0;
			try {
				//Name,Id,Version,Source
				//int zeroethColumnStart = 0;
				if (headerRow != null) {
					firstColumnStart = headerRow.IndexOf("Id");
					secondColumnStart = headerRow.IndexOf("Version");
					thirdColumnStart = headerRow.IndexOf("Source");
			// outBox_val.AppendText(Environment.NewLine + "firstColumnStart: "+ firstColumnStart+ " secondColumnStart: "+ secondColumnStart+ " thirdColumnStart: "+ thirdColumnStart + " headerRow.Length: "+ headerRow.Length);
				}
			} catch (Exception err){
			outBox_val.AppendText(Environment.NewLine + "err: "+ err);
				// string_out = "";
			}
				string strung_in = "";
					
				//outBox_val.AppendText(Environment.NewLine + "Test Test Test");
				foreach (string strung in strung_out) {
					// outBox_val.AppendText(Environment.NewLine + "strung" + strung);
					int firstLoc = (firstColumnStart - 0 -1);
					int secondLoc = (secondColumnStart - firstColumnStart -1);
					int thirdLoc = (thirdColumnStart - secondColumnStart -1);
					int endLoc = (headerRow.Length - thirdColumnStart+1);

					strung_in += strung.Substring(0,firstLoc).Trim();
					strung_in += ",";
					strung_in += strung.Substring(firstColumnStart,secondLoc).Trim();
					strung_in += ",";
					strung_in += strung.Substring(secondColumnStart,thirdLoc).Trim();
					strung_in += ",";
					strung_in += strung.Substring(thirdColumnStart,endLoc).Trim();
					strung_in += "\n";
				}
				string_out = string.Join("\n",strung_in);
		return string_out;
		}






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
double result = DateTime.Now.Subtract(DateTime.MinValue).TotalSeconds;

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


		Minimize - OG OPB has UE on minimize bug.
		public void picMinimize_Click(object sender, EventArgs e) 
		{
           try
           {
               panelUC.Visible = false;//change visible status of your form, etc.
               this.WindowState = FormWindowState.Minimized; //minimize
               minimizedFlag = true;//set a global flag
           }
           catch (Exception) {

           }

		} // This is the "expanded" style that I do not like. 

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
