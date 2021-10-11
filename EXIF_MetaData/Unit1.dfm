object Form1: TForm1
  Left = 220
  Top = 130
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'EXIF MetaData'
  ClientHeight = 433
  ClientWidth = 626
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -14
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 120
  TextHeight = 16
  object Label1: TLabel
    Left = 336
    Top = 16
    Width = 16
    Height = 32
    Caption = '1'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 1861375
    Font.Height = -27
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Label4: TLabel
    Left = 336
    Top = 48
    Width = 16
    Height = 32
    Caption = '2'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 1861375
    Font.Height = -27
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Label5: TLabel
    Left = 376
    Top = 56
    Width = 234
    Height = 48
    Caption = 
      'Vous retravaillez le bitmap.'#13'Ici simple ajout d'#39'un rectangle rou' +
      'ge au centre.'
    WordWrap = True
  end
  object Label6: TLabel
    Left = 336
    Top = 104
    Width = 16
    Height = 32
    Caption = '3'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 1861375
    Font.Height = -27
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Label7: TLabel
    Left = 376
    Top = 144
    Width = 238
    Height = 32
    AutoSize = False
    Caption = 'Vous pouvez ajouter une description de l'#39'image (legende).'
    WordWrap = True
  end
  object Label8: TLabel
    Left = 376
    Top = 360
    Width = 230
    Height = 64
    Caption = 
      'Le bitmap a ete sauvegarde dans le dossier de l'#39'application, sou' +
      's le nom "TestExif.jpg".'#13'Retour a l'#39'etape 1 pour ouvrir ce fichi' +
      'er.'
    WordWrap = True
  end
  object Label9: TLabel
    Left = 336
    Top = 216
    Width = 16
    Height = 32
    Caption = '4'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 1861375
    Font.Height = -27
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Label10: TLabel
    Left = 376
    Top = 216
    Width = 235
    Height = 80
    Caption = 
      'Vous pouvez decider de ne pas inclure toutes les donnees Exif.'#13'S' +
      'i vous decochez, seules la date de prise de vue et la descriptio' +
      'n seront sauvegardees.'
    WordWrap = True
  end
  object Label11: TLabel
    Left = 336
    Top = 328
    Width = 16
    Height = 32
    Caption = '5'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 1861375
    Font.Height = -27
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object EditDescription: TEdit
    Left = 376
    Top = 184
    Width = 241
    Height = 24
    TabOrder = 2
  end
  object OpenJpegBtn: TButton
    Left = 376
    Top = 16
    Width = 241
    Height = 25
    Caption = 'Open Jpeg'
    TabOrder = 0
    OnClick = OpenJpegBtnClick
  end
  object ChangeBmpBtn: TButton
    Left = 376
    Top = 112
    Width = 241
    Height = 25
    Caption = 'Process Bitmap'
    TabOrder = 1
    OnClick = ChangeBmpBtnClick
  end
  object SaveBitmapBtn: TButton
    Left = 376
    Top = 328
    Width = 241
    Height = 25
    Caption = 'Save Bitmap to Jpeg'
    TabOrder = 4
    OnClick = SaveBitmapBtnClick
  end
  object IncludeExifCB: TCheckBox
    Left = 376
    Top = 304
    Width = 241
    Height = 17
    Caption = 'Inclure toutes les donnees'
    Checked = True
    State = cbChecked
    TabOrder = 3
  end
  object GroupBox1: TGroupBox
    Left = 8
    Top = 8
    Width = 321
    Height = 417
    TabOrder = 5
    object Image1: TImage
      Left = 16
      Top = 47
      Width = 289
      Height = 250
      Center = True
      Stretch = True
    end
    object Label3: TLabel
      Left = 16
      Top = 312
      Width = 51
      Height = 16
      Caption = 'Exif data'
    end
    object Label2: TLabel
      Left = 16
      Top = 23
      Width = 124
      Height = 16
      Caption = 'Image with EXIF data'
    end
    object Memo1: TMemo
      Left = 16
      Top = 336
      Width = 289
      Height = 65
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 0
    end
  end
  object OpenDialog1: TOpenDialog
    Filter = 'Jpeg|*.jpg'
    Left = 576
    Top = 16
  end
end
