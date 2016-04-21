program ThumbnailsViewer;

uses
  Vcl.Forms,
  unit_thumbnailsviewer in 'unit_thumbnailsviewer.pas' {Form_Thumbnails};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm_Thumbnails, Form_Thumbnails);
  Application.Run;
end.
