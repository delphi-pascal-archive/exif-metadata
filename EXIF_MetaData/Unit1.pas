unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, Jpeg, StdCtrls, ExtCtrls;

type
  TForm1 = class(TForm)
    OpenDialog1: TOpenDialog;
    EditDescription: TEdit;
    Label1: TLabel;
    OpenJpegBtn: TButton;
    Label4: TLabel;
    ChangeBmpBtn: TButton;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    SaveBitmapBtn: TButton;
    Label8: TLabel;
    Label9: TLabel;
    Label10: TLabel;
    IncludeExifCB: TCheckBox;
    Label11: TLabel;
    GroupBox1: TGroupBox;
    Image1: TImage;
    Label3: TLabel;
    Memo1: TMemo;
    Label2: TLabel;
    procedure OpenJpegBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ChangeBmpBtnClick(Sender: TObject);
    procedure SaveBitmapBtnClick(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
  end;

var
  Form1: TForm1;

implementation

uses ImageMD;

var
  ImageMetaData: TIMageMetaData;
  BitmapSource: TBitmap;

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
 ImageMetaData:= TImageMetaData.Create;
 BitmapSource:= TBitmap.Create;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
 ImageMetaData.Free;
 BitmapSource.Free;
end;

procedure TForm1.OpenJpegBtnClick(Sender: TObject);
var
 Bmp: TBitmap;
 Jpg: TJpegImage;
begin
 if OpenDialog1.Execute then
   begin
      Bmp:= TBitmap.Create;
      Jpg:= TJpegImage.Create;
      try
         with ImageMetaData do
            if ReadExif(Opendialog1.filename, Bmp) then
            begin
               DisplayTags(Memo1);
               Image1.Picture.Bitmap.Assign(Bmp);
               Image1.Refresh;
            end
            else
            begin
               Memo1.Clear;
               Memo1.Lines.Add('Pas de données exif');
               Image1.Picture.Bitmap:= nil;
            end;
         Application.ProcessMessages;
         Jpg.LoadFromFile(OpenDialog1.FileName);
         BitmapSource.Assign(Jpg);
      finally
         Bmp.Free;
         Jpg.Free;
      end;
   end;
end;

procedure TForm1.ChangeBmpBtnClick(Sender: TObject);
var
  R: TRect;
begin
  with BitmapSource do
   begin
     R.Left:= Width div 4;
     R.Top:= Height div 4;
     R.Right:= R.Left + (Width div 2);
     R.Bottom:= R.Top + (Height div 2);
     Canvas.Brush.Color:= clRed;
     Canvas.FillRect(R);
   end;
end;

procedure TForm1.SaveBitmapBtnClick(Sender: TObject);
var
 Value1, Value2: variant;
begin
  with ImageMetaData do
   begin
       if not IncludeExifCB.Checked then
       begin
          // mémorisation de la date original
          GetExifTag(TagID_OriginalDate, Value1, Value2);
          // on met à blanc les valeurs des Tags
          InitializeTags;
          // assignation de la date
          if String(Value1) <> '' then
            SetExifTag(TagID_OriginalDate, Value1, '');
       end;
       // assignation de la légende
       SetDescription(EditDescription.Text);
       // sauvegarde du fichier
       SaveToJpeg(BitmapSource, ExtractFilePath(Application.ExeName) + 'TestExif.jpg', 200);
   end;
end;

end.
