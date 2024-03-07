//Copyright 2022-2024 Microsoft Corporation
//Author: Stephen Gillie
//Title: WinGet Approval Pipeline v3.-94.1
//Created: 1/19/2024
//Updated: 3/6/2024
//Notes: Utilities to streamline evaluating 3rd party PRs.
//Update log:
//3.-94.1 - Rearrange functions, map locations for future function ports. 
//3.-94.0 - Port ApprovePR. Successfully approve PR with application!
//3.-95.0 - Port InvokeGitHubPRRequest as InvokeGitHubRequest wrapper.
//3.-96.0 - Port InvokeGitHubRequest as webRequest wrapper.
//3.-97.0 - Develop JSON functions and serialization processes. 
//3.-98.0 - Modify webRequest to support more verbs than just GET, and optionally provide authentication headers.
//3.-99.2 - Import GitHub token from file (shift left!)
//3.-99.1 - "Port" C# window class and rect struct back from a C#-in-PS Add-Type call.
//3.-99.0 - Add button & RichTextArea construction functions, rebuild application top. 
//3.-100.0 - Use the tried-and-true strategy of "Start with the OPB and delete what you don't need."






/*Contents: (Remaining functions to port or depreciate: 94)
- Init vars (?)
- Boilerplate (?)
- UI top-of-box (?)
	- Menu (?)
- Tabs (3)
- Automation Tools (7)
- PR tools (7)
- Network tools (1)
- Validation Starts Here (6)
- Manifests Etc (7)
- VM Image Management (3)
- VM Pipeline Management (6)
- VM Status (5)
- VM Versioning (3)
- VM Orchestration (6)
- File Management (8)
- Inject into files on disk (2)
- Inject into PRs (4)
- Timeclock (4)
- Reporting (5)
- Clipboard (5)
- Etc (7)
- PR Watcher Utility functions (2)
- Powershell equivalency (?)
- VM Window management (3)
*/






//Init vars
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Imaging;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using System.Web.Script.Serialization;

namespace WinGetApprovalNamespace {
    public class WinGetApprovalPipeline : Form {
		//vars
        public int build = 343;//Get-RebuildPipeApp
		public string appName = "WinGetApprovalPipeline";
		public string appTitle = "WinGet Approval Pipeline - Build ";
		public static string owner = "microsoft";
		public static string repo = "winget-pkgs";

		//public IPAddress ipconfig = (ipconfig);
		//public IPAddress remoteIP = ([ipaddress](($ipconfig[($ipconfig | Select-String "vEthernet").LineNumber..$ipconfig.length] | Select-String "IPv4 Address") -split ": ")[1]).IPAddressToString;
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

		public string defaultSite = "#141505";
		public int displayLine = 0;

		public static string PRRegex = "[0-9]{5,6}";
		public static string hashPRRegex = "[//]"+PRRegex;
		public static string hashPRRegexEnd = hashPRRegex+"$";
		public static string colonPRRegex = PRRegex+"[:]";
		

		public string GitHubTokenFile = "C:\\Users\\v-sgillie\\Documents\\PowerShell\\ght.txt";
		public string GitHubToken;
		public int GitHubRateLimitDelay = 333;

		public bool debuggingView = false;
		public Process[] processes = Process.GetProcesses(); //Get-Process
		JavaScriptSerializer serializer = new JavaScriptSerializer();//JSON

		//ui
		public RichTextBox outBox = new RichTextBox();
		public RichTextBox valBox, vmBox;
		public System.Drawing.Bitmap myBitmap;//Depreciate
		public System.Drawing.Graphics pageGraphics;//Depreciate?
		public Panel pagePanel;
		public ContextMenuStrip contextMenu1;//Menu?

		public TextBox urlBox;
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

		public void PopulateToken() {
			try {
				// Open the text file using a stream reader.
				using (var sr = new StreamReader(GitHubTokenFile)) {
					// Read the stream as a string, and write the string to the console.
					GitHubToken = sr.ReadToEnd();
				}
			} catch (IOException e) {
				MessageBox.Show("The token file "+GitHubTokenFile+" could not be read:\n" + e.Message, "Error");
			}
		}
		
        public WinGetApprovalPipeline() {
			PopulateToken();
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
   
        } // end WinGetApprovalPipeline		

        public void loadNewPage() {

//Download HTML file
//Parse HTML to Document variable
//Write Document variable to page
//Interpret Javascript to modify Document variable
			//history.Add(urlBox.Text);
			history[historyIndex] = urlBox.Text;
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
 			 			
			drawOutBox(ref vmBox, col0, row0, gridItemWidth*6,gridItemHeight*5, "vmBox text", "vmBox");

			drawButton(ref btn27, col6, row0, gridItemWidth*2, gridItemHeight, "Work Search", Work_Search_Button_Click);
			drawUrlBox(ref urlBox,col8, row0, gridItemWidth*2,gridItemHeight,defaultSite);
 			
			drawButton(ref btn2, col6, row1, gridItemWidth, gridItemHeight, "Needs Feedback", Needs_Feedback_Button_Click); 			drawButton(ref btn3, col7, row1, gridItemWidth, gridItemHeight, "Add Waiver", Add_Waiver_Button_Click); 			drawButton(ref btn4, col8, row1, gridItemWidth, gridItemHeight, "Retry", Retry_Button_Click); 			drawButton(ref btn5, col9, row1, gridItemWidth, gridItemHeight, "Approved", Approved_Button_Click); 			 			drawButton(ref btn6, col6, row2, gridItemWidth, gridItemHeight, "Blocking Issue", Blocking_Issue_Button_Click); 			drawButton(ref btn7, col7, row2, gridItemWidth, gridItemHeight, "Check Installer", Check_Installer_Button_Click); 			drawButton(ref btn8, col8, row2, gridItemWidth, gridItemHeight, "Project File", Project_File_Button_Click); 			drawButton(ref btn9, col9, row2, gridItemWidth, gridItemHeight, "Closed", Closed_Button_Click); 			
 			drawButton(ref btn14, col6, row3, gridItemWidth, gridItemHeight, "Defender Fail", Defender_Fail_Button_Click); 			drawButton(ref btn15, col7, row3, gridItemWidth, gridItemHeight, "Automation Block", Automation_Block_Button_Click);
 			drawButton(ref btn16, col8, row3, gridItemWidth, gridItemHeight, "Installer Not Silent", Installer_Not_Silent_Button_Click);
 			drawButton(ref btn17, col9, row3, gridItemWidth, gridItemHeight, "Installer Missing", Installer_Missing_Button_Click);			
			drawButton(ref btn24, col6, row4, gridItemWidth, gridItemHeight, "Needs PackageUrl", Needs_PackageUrl_Button_Click);
			drawButton(ref btn25, col7, row4, gridItemWidth, gridItemHeight, "Manifest One Per PR", Manifest_One_Per_PR_Button_Click);
			drawButton(ref btn26, col8, row4, gridItemWidth, gridItemHeight, "Merge Conflicts", Merge_Conflicts_Button_Click);
 			drawButton(ref btn13, col9, row4, gridItemWidth, gridItemHeight, "Network Blocker", Network_Blocker_Button_Click);			
			drawOutBox(ref valBox, col0, row5, this.ClientRectangle.Width,gridItemHeight*4, "valBox text", "valBox");
			 			drawButton(ref btn10, col0, row9, gridItemWidth, gridItemHeight, "Approving", Approving_Button_Click); 			drawButton(ref btn11, col1, row9, gridItemWidth, gridItemHeight, "IEDS", IEDS_Button_Click);			drawButton(ref btn18, col2, row9, gridItemWidth, gridItemHeight, "Validating", Validating_Button_Click);
			drawButton(ref btn19, col3, row9, gridItemWidth, gridItemHeight, "Idle", Idle_Button_Click);

 	   }// end drawGoButton

		public void OnResize(object sender, System.EventArgs e) {
			//outBox.Height = ClientRectangle.Height - gridItemHeight;
			//outBox.Width = ClientRectangle.Width - 0;
			//urlBox.Width = ClientRectangle.Width - gridItemWidth*2;
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
			string AboutText = "Old Person Browser" + Environment.NewLine;
			AboutText += "(c) 2020 Gilgamech Technologies" + Environment.NewLine;
			AboutText += "" + Environment.NewLine;
			AboutText += "Report bugs (stuff not working):" + Environment.NewLine;
			AboutText += "OldPersonBrowser-Bugs@Gilgamech.com" + Environment.NewLine;
			AboutText += "Request new features on Patreon:" + Environment.NewLine;
			AboutText += "patreon.com/Gilgamech" + Environment.NewLine;
			MessageBox.Show(AboutText);
		} // end Link_Click
/*
Gilgamech is making web browsers, games, self-driving RC cars, and other technology sundries.
*/

		public void WordWrap_Click (object sender, EventArgs e) {
			// Link
			// historyIndex++;
			// urlBox.Text = e.LinkText;
			// history[historyIndex] = urlBox.Text;
			// loadNewPage();
		} // end Link_Click

		public void TextBox_Link (object sender, LinkLabelLinkClickedEventArgs e) {
			Array.Resize(ref history, history.Length + 1);
			historyIndex++;
			history[historyIndex] = e.Link.LinkData.ToString();
			// urlBox.Text = history[historyIndex];
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
//AddWaiver
//SearchGitHub
//CannedMessage - Ready
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
			string commit = "";//((prData["commit"]["url"].split("/"))[-1]);

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
			string commit = "";//((prData["commit"]["url"].split("/"))[-1]);
			string Url = GitHubApiBaseUrl+"/pulls/"+PR+"/reviews";


			Dictionary<string,object> Response = new Dictionary<string, object>();
			Response.Add("body",Data);
			Response.Add("commit",commit);
			Response.Add("event","APPROVE");
			string Body = ToJson(Response);
			
			string out_var = InvokeGitHubRequest(Url,"Post",Body);
			return out_var;
		}

//AddGitHubReviewComment - Ready
//GetBuildFromPR - Ready
//GetLineFromCommitFile
//GetPRApproval
//ReplyToPR
//NonstandardComments - Ready
//PRStateFromComment - Ready






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

//PRInstallerStatusInnerWrapper - Ready






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
//ManifestOtherAutomation
//ManifestFile
//ManifestListing
//ListingDiff
//OSFromVersion






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
//SetStatus
//GetStatus
//WriteStatus - Ready
//ResetStatus
//RebuildStatus






//VM Versioning
//GetVMVersion - Ready
//SetVMVersion - Ready
//RotateVMs






//VM Orchestration
//VMCycle
//GetMode - Ready
//SetMode - Ready
//ConnectedVM
//NextFreeVM
//RedoCheckpoint






//File Management
//SecondMatch
//RotateLog
//RemoveFileIfExist
//LoadFileIfExists
//GetFileFromGitHub - Ready
//ManifestEntryCheck
//DecodeGitHubFile - Ready
//GetCommitFIle






//Inject into files on disk
//AddToValidationFile
//AddInstallerSwitch






//Inject into PRs
//UpdateHashInPR
//UpdateHashInPR2
//UpdateArchInPR
//DependencyToPR






//Timeclock
//SetTImeclock
//GetTimeclock
//HoursWorkedToday
//GetTimeRunning - Ready






//Reporting
//AddPRToRecord - Ready
//PRPopulateRecord
//GetPRFromRecord
//PRReportFromRecord
//PRFullReport






//Clipboard
//PRNumber - Ready
//SortedClipboard - Ready
//OpenAllURLs
//OpenPRInBrowser
//YamlValue - Ready






//Etc
//TestAdmin - Ready
//LazySearch
//TrackerProgress - Ready
//ArraySum - Ready
//GitHubRateLimit - Ready
//GetValidationData
//AddValidationData






//PR Watcher Utility functions
//GetSandbox
//PadRight - Ready






		//Powershell equivalency imperatives
		//Start-Sleep = Thread.Sleep(GitHubRateLimitDelay);
		//Get-Process = Process[] processes //Above;
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

		public dynamic FromJson(string input_string) {
			dynamic output_dynamic = new System.Dynamic.ExpandoObject();
			output_dynamic = serializer.Deserialize<dynamic>(input_string);
			return output_dynamic;
		}
			
		public string ToJson(dynamic input_dynamic) {
			string output_string;
			output_string = serializer.Serialize(input_dynamic);
			return output_string;
		}






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
				
				For (n = 1;n -lt VMs.count;n++) {
					VM = VMs[n]
					
					Left = (Base.left - (100 * n))
					Top = (Base.top + (66 * n))
					TrackerVMWindowSet VM Left Top 1029 860
				}
			}
*/
		}






		//Depreciate or bust
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
            item.MenuItems.Add("Show Scroll Position", new EventHandler(GetScroll_Position));
        item = new MenuItem("Help");
        this.Menu.MenuItems.Add(item);
            item.MenuItems.Add("About", new EventHandler(About_Click));
	   }// end drawMenuBar

		//Utility
        [DllImport("user32.dll")]
        private static extern int SendMessage(IntPtr hwndLock, Int32 wMsg, Int32 wParam, ref Point pt);

        public static Point GetScrollPos(RichTextBox txtbox) {
            const int EM_GETSCROLLPOS = 0x0400 + 221;
            Point pt = new Point();

            SendMessage(txtbox.Handle, EM_GETSCROLLPOS, 0, ref pt);
            return pt;
        }

        public static void SetScrollPos(Point pt,RichTextBox txtbox) {
            const int EM_SETSCROLLPOS = 0x0400 + 222;

            SendMessage(txtbox.Handle, EM_SETSCROLLPOS, 0, ref pt);
        }        

        public void GetScroll_Position(object sender, EventArgs e) {
			MessageBox.Show("x = "+GetScrollPos(outBox).X);
        }// end GetScroll_Position

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
			// urlBox.Text = history[historyIndex];
			loadNewPage();
		}// end Save_Click
		
		public void Navigate_Forward(object sender, EventArgs e) {
			Array.Resize(ref history, history.Length + 1);
			historyIndex++;
			// urlBox.Text = history[historyIndex];
			loadNewPage();
		}// end Save_Click
		
		//Demo variables and functions
		dynamic myDynamic = new { PropertyTrue = true, PropertyTwo = 2, PropertyNumber = "Number", MyMethod = new Func<int>(() =>  {return (22+33);})};
		
		public void Work_Search_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			WebHeaderCollection headers = new WebHeaderCollection();
			response_out = webRequest(Url, WebRequestMethods.Http.Get,"",true);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Needs_Feedback_Button_Click(object sender, EventArgs e) {
			// string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = Clipboard.GetText();
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Add_Waiver_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Retry_Button_Click(object sender, EventArgs e) {
			string Path = "issues";
			string Type = "comments";
			int PR = 141505;
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

			valBox.AppendText(Environment.NewLine + WebRequestMethods.Http.Get + " " +  Url + " - " + response_out);
        }// end Approved_Button_Click
		
        public void Approved_Button_Click(object sender, EventArgs e) {
			string response_out = "";
			int PR = Int32.Parse(urlBox.Text.Replace("#",""));
			response_out = ApprovePR(PR);
			valBox.AppendText(Environment.NewLine + "PR "+ PR + ": " + response_out);
        }// end Approved_Button_Click
		
        public void Blocking_Issue_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Check_Installer_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Project_File_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Closed_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Defender_Fail_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Automation_Block_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Installer_Not_Silent_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Installer_Missing_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Needs_PackageUrl_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Manifest_One_Per_PR_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Merge_Conflicts_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Network_Blocker_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
		//Modes
        public void Approving_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void IEDS_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Validating_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click
		
        public void Idle_Button_Click(object sender, EventArgs e) {
			string Url = "https://api.github.com/rate_limit";
			string response_out = "";
			response_out = InvokeGitHubRequest(Url);
			valBox.AppendText(Environment.NewLine + response_out);
        }// end Approved_Button_Click

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
