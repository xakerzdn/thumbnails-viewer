unit unit_ThumbnailsViewer;

interface

{$WARN UNIT_PLATFORM OFF}

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Types,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.FileCtrl,
  Vcl.ComCtrls,
  Vcl.Grids,
  Vcl.Imaging.jpeg,
  Vcl.Menus,
  System.SyncObjs,
  System.UITypes,
  Winapi.ShellAPI;

type
  TThread_ListFillImages = class(TThread)
  private
  protected
    function AllowableExtension(FileExtension: String): Boolean;
    procedure FillListView;

    procedure Execute; override;
  public
  var
    ListAllowFormats: TStringList;
    FFileName: String;
    FDirectory: String;
    BMP: TBitmap;
    constructor Create(Suspended: Boolean; Heigth, Width: Integer;
      Directory: String); overload;
    destructor Destroy; override;
  end;

type
  TForm_Thumbnails = class(TForm)
    Splitter: TSplitter;
    DirectoryListBox: TDirectoryListBox;
    ListView: TListView;
    procedure DirectoryListBoxChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure DirectoryListBoxKeyPress(Sender: TObject; var Key: Char);
    procedure ListViewDblClick(Sender: TObject);
  private
  var
    ImageList: TImageList;
    PopupMenu: TPopupMenu;

  const
    WM_FILL_LIST_IMAGES = WM_USER + 1;

    procedure StartThreadFillListImage(var Msg: TMessage);
      message WM_FILL_LIST_IMAGES;
    procedure PopupMenuOnClick(Sender: TObject);
  protected
  public
  published
  end;

var
  Form_Thumbnails: TForm_Thumbnails;
  Thread_ListFillImages: TThread_ListFillImages;

implementation

{$R *.dfm}

procedure TForm_Thumbnails.StartThreadFillListImage(var Msg: TMessage);
begin
  ListView.Clear;
  if Assigned(Thread_ListFillImages) then
    Thread_ListFillImages.Free;
  Thread_ListFillImages := TThread_ListFillImages.Create(False,
    ImageList.Height, ImageList.Width, DirectoryListBox.Directory);
end;

procedure TForm_Thumbnails.DirectoryListBoxChange(Sender: TObject);
begin
  PostMessage(Handle, WM_FILL_LIST_IMAGES, 0, 0);
end;

procedure TForm_Thumbnails.DirectoryListBoxKeyPress(Sender: TObject;
  var Key: Char);
begin
  if Key = #13 then
    DirectoryListBoxChange(Sender);
end;

procedure TForm_Thumbnails.FormCreate(Sender: TObject);
const
  DisksLength = 105;
var
  MI: TMenuItem;
  Disks: WideString;
  i: Integer;
begin
  ImageList := TImageList.Create(Self);
  ImageList.SetSize(68, 68);
  PopupMenu := TPopupMenu.Create(Self);
  PopupMenu.AutoHotkeys := maManual;
  ListView.LargeImages := ImageList;
  DirectoryListBox.PopupMenu := PopupMenu;
  DirectoryListBox.Directory := GetCurrentDir;
  DirectoryListBoxChange(Sender);
  SetLength(Disks, DisksLength);
  i := GetLogicalDriveStrings(105, @Disks[1]);
  if i > 0 then
    for i := 0 to (i div 4) - 1 do
    begin
      MI := TMenuItem.Create(PopupMenu);
      MI.Caption := PWideChar(@Disks[i * 4 + 1]);
      MI.OnClick := PopupMenuOnClick;
      PopupMenu.Items.Add(MI);
    end;
end;

procedure TForm_Thumbnails.FormDestroy(Sender: TObject);
begin
  if Assigned(Thread_ListFillImages) then
    Thread_ListFillImages.Free;
  PopupMenu.Free;
  ImageList.Free;
end;

procedure TForm_Thumbnails.ListViewDblClick(Sender: TObject);
begin
  if Assigned(ListView.ItemFocused) then
    ShellExecute(Handle, 'open', PWideChar(ListView.ItemFocused.Caption), '',
      '', SW_NORMAL);
end;

procedure TForm_Thumbnails.PopupMenuOnClick(Sender: TObject);
begin
  try
    DirectoryListBox.Directory := TMenuItem(Sender).Caption;
  except
    on E: Exception do
      MessageDlg('Error: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

{ TThread_ListFillImages }

function TThread_ListFillImages.AllowableExtension(FileExtension
  : String): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to ListAllowFormats.Count - 1 do
    if ListAllowFormats[i] = LowerCase(FileExtension) then
    begin
      Result := True;
      Break;
    end;
end;

constructor TThread_ListFillImages.Create(Suspended: Boolean;
  Heigth, Width: Integer; Directory: String);
begin
  ListAllowFormats := TStringList.Create;
  ListAllowFormats.Add('.jpeg');
  ListAllowFormats.Add('.jpg');
  ListAllowFormats.Add('.bmp');
  FDirectory := Directory;
  BMP := TBitmap.Create;
  BMP.Height := Heigth;
  BMP.Width := Width;
  BMP.Transparent := True;
  inherited Create(Suspended);
end;

destructor TThread_ListFillImages.Destroy;
begin
  inherited Destroy;
  BMP.Free;
  ListAllowFormats.Free;
end;

procedure TThread_ListFillImages.Execute;
var
  SR: TSearchRec;
  JPG: TJPEGImage;
begin
  inherited;
  JPG := TJPEGImage.Create;
  try
    try
      if System.SysUtils.FindFirst(FDirectory + '\*.*', faAnyFile, SR) = 0 then
      begin
        repeat
          FFileName := SR.Name;
          if AllowableExtension(ExtractFileExt(SR.Name)) then
            if (LowerCase(ExtractFileExt(SR.Name)) = '.jpeg') or
              (LowerCase(ExtractFileExt(SR.Name)) = '.jpg') then
            begin
              JPG.LoadFromFile(FDirectory + '\' + SR.Name);
              JPG.Scale := jsEighth;
              JPG.CompressionQuality := 1;
              if Assigned(BMP.Canvas) then
                try
                  BMP.Canvas.Lock;
                  try
                    BMP.Canvas.StretchDraw(System.Types.Rect(0, 0, BMP.Height,
                      BMP.Width), JPG);
                  finally
                    BMP.Canvas.Unlock;
                  end;
                except
                  on E: Exception do
                    // TODO:Internal log
                end;
              Synchronize(FillListView);
            end
            else if (ExtractFileExt(SR.Name) = '.bmp') then
            begin
              BMP.LoadFromFile(FDirectory + '\' + SR.Name);
              try
                BMP.Canvas.Lock;
                try
                  BMP.Canvas.StretchDraw(System.Types.Rect(0, 0, BMP.Height,
                    BMP.Width), BMP);
                finally
                  BMP.Canvas.Unlock;
                end;
              except
                on E: Exception do
                  // TODO:Internal log
              end;
              Synchronize(FillListView);
            end;
        until (FindNext(SR) <> 0) or (Terminated);
        FindClose(SR);
      end;
    except
      on E: Exception do
        MessageDlg('Error: ' + E.Message, mtError, [mbOK], 0);
    end;
  finally
    JPG.Free;
  end;
end;

procedure TThread_ListFillImages.FillListView;
var
  LI: TListItem;
begin
  if not Terminated then
  begin
    LI := Form_Thumbnails.ListView.Items.Add;
    LI.Caption := FFileName;
    LI.ImageIndex := Form_Thumbnails.ImageList.Add(BMP, nil);
  end;
end;

end.
