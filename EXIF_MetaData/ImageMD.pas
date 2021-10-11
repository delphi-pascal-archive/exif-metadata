unit ImageMD;

{ TImageMetaData
  Auteur : ThWilliam
  Date : 13 octobre 2007 }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, jpeg,
  StdCtrls, Math;

type
  TExifTag = record
    ID: word;  // type de la donnée (ex : $010F = fabricant de l'appareil)
    Typ: word; // format du type : 2 = Pchar; 3 = Word, 4 = Cardinal...
    Count: cardinal; //nombre de données du type défini
    Offset: cardinal; // valeur de la donnée ou Offset vers cette valeur si celle-ci ne peut pas être stockée sur 4 octets
  end;

  TExifFileStream = class(TFileStream)
  private
    FMotorolaOrder: boolean;
    FExifStart: cardinal;
    FNbDirEntries: word;
    FIfd0Start: cardinal;
    function ReadString(Count: integer): string;
    function ReadWord: word;
    function ReadLong: cardinal;
    function ReadTag: TExifTag;
    function HasExif: boolean;
    function HasThumbNail(var ThumbStart, ThumbLen: cardinal): boolean;
    function GetThumbNail(ThumbStart, ThumbLen: cardinal; Bitmap: TBitmap): boolean;
  public
    constructor Create(const FileName: string; Mode: Word);
  end;

  TExifTagItem = record
     Name: string;
     Id: word;
     Typ: word;
     Count: cardinal;
     Dir: byte; // 0 = répertoire IFD0, 1 = sous-répertoire de l'IFD0
     Value: variant;
     Value2: variant;
  end;

  TExifTagsArray = array[0..17] of TExifTagItem;

  TImageMetaData = class(Tobject)
  private
    FFileStream: TExifFileStream;
    TagsArray: TExifTagsArray;
    TagThumb1: TExifTag;
    TagThumb2: TExifTag;
    TagThumb3: TExifTag;
    TagThumb4: TExifTag;
    TagThumb5: TExifTag;
    TagSubdir: TExifTag;
    procedure ReadTagValues(ExifTag: TExifTag);
  public
    constructor Create;
    function ReadExif(FileName: string; ThumbNail: TBitmap): boolean;
    procedure InitializeTags;
    function SaveToJpeg(Bitmap: TBitmap; FileName: string; ThumbMaxSize: integer): boolean;
    procedure DisplayTags(Memo: TMemo);
    procedure GetExifTag(TagID: word; var Value1, Value2: variant);
    procedure SetExifTag(TagID: word; Value1, Value2: variant);
    procedure SetDescription(Value: string);
  end;


const  // ceci ne fait que simplifier la manipulation des Tags
  TagID_Description = $010E;
  TagID_Maker = $010F;
  TagID_Model = $0110;
  TagID_Date = $0132;
  TagID_Speed = $829A;
  TagID_Aperture = $829D;
  TagID_ExpoProgram = $8822;
  TagID_Iso = $8827;
  TagID_OriginalDate = $9003;
  TagID_MeteringMode = $9207;
  TagID_Focal = $920A;
  TagID_ImageWidth = $A002;
  TagID_ImageHeight = $A003;
  TagID_WhiteBalance = $A403;
  TagID_Focal35mm = $A405;
  TagID_Contrast = $A408;
  TagID_Saturation = $A409;
  TagID_Sharpness = $A40A; // accentuation

  TagID_SubDir = $8769; // sous-répertoire de l'IFD0
  TagID_ThumbOffset = $0201; // offset vers vignette
  TagID_ThumbLen = $0202; // taille de la vignette

implementation

{ la procedure SwapBytes est de Florenth. Merci à lui}
procedure SwapBytes(var Data; Count: Byte);
var
  B: PByte;
  E: PByte;
  T: Byte;
begin
  B := PByte(@Data);
  E := PByte(Integer(B) + Count - 1);
  while Integer(B) < Integer(E) do
  begin
    T := E^;
    E^:= B^;
    B^:= T;
    Inc(B);
    Dec(E);
  end;
end;

function SwapLong(Value: Cardinal): Cardinal;
begin
   SwapBytes(Value, SizeOf(Cardinal));
   Result:= Value;
end;

function SwapWord(Value: Word): Word;
begin
   SwapBytes(Value, SizeOf(Word));
   Result:= Value;
end;

{TExifFileStream}

constructor TExifFileStream.Create(const FileName: string; Mode: Word);
begin
  inherited Create(FileName, Mode);
  FMotorolaOrder:= false;
  FNbDirEntries:= 0;
  FExifStart:= 0;
  FIfd0Start:= 0;
end;

function TExifFileStream.ReadString(Count: integer): string;
begin
  SetLength(Result, Count);
  ReadBuffer(Result[1], Count);
end;

function TExifFileStream.ReadWord: word;
begin
  ReadBuffer(Result, SizeOf(Result));
  if FMotorolaOrder then Result:= SwapWord(Result);
end;

function TExifFileStream.ReadLong: cardinal;
begin
  ReadBuffer(Result, SizeOf(Result));
  if FMotorolaOrder then Result:= SwapLong(Result);
end;

function TExifFileStream.ReadTag: TExifTag;
begin
   ReadBuffer(Result,SizeOf(Result));
   if FMotorolaOrder then
      with Result do
      begin
         ID:= SwapWord(Id);
         Typ:= SwapWord(Typ);
         Count:= SwapLong(Count);
         if Typ = 3 then Offset:= (Offset shr 8) and $FF
             else Offset:= SwapLong(Offset);
      end;
end;

function TExifFileStream.HasExif: boolean;
const
  IOrder: string = #$49#$49#$2A#$00;
  MOrder: string = #$4D#$4D#$00#$2A;
var
  BufByte: byte;
  S: string;
  ExifOffset: cardinal;
  I: integer;
begin
  Result:= false;
  if ReadString(2) = #$FF#$D8 then  // c'est un fichier Jpeg, commence par $FF$D8
  begin
      // recherche du marqueur Exif APP1 (= $FF$E1)
      I:= 0;
      while (I < 5) and (Position < Size - 100) do
      begin
          ReadBuffer(BufByte, SizeOf(BufByte));
          if BufByte = $FF then
          begin
              Inc(I);
              ReadBuffer(BufByte, SizeOf(BufByte));
              if BufByte = $E1 then  // on a trouvé le marqueur
              begin
                  // on saute l'en-tête $45$78$69$66$00$00 + les 2 octets contenant la longueur de la section APP1
                  Seek(8, soFromCurrent);
                  // lecture de l'alignement
                  S:= ReadString(4);
                  if S = IOrder then FMotorolaOrder:= false
                     else if S = MOrder then FMotorolaOrder:= true
                        else
                          Exit;
                  // mémorise le départ des données Exif : tous les offset sont calculés
                  // à partir de $49 ou $4D
                  FExifStart:= Position -4;
                  // lecture de l'offset vers le répertoire IFD0 (en général = 8)
                  ExifOffset:= ReadLong;
                  Position:= FExifStart + ExifOffset;
                  // lecture du nombre d'entrées de l'IFD0
                  FNbDirEntries:= ReadWord;
                  Result:= (FNbDirEntries > 0);
                  FIfd0Start:= Position; // départ des entrées de l'IFD0;
                  Exit;
              end;
          end;
      end;
  end
  else
  begin
      Position:= 0;
      S:= ReadString(4);
      if S = IOrder then FMotorolaOrder:= false  // fichier TIFF alignement Intel
          else if S = MOrder then FMotorolaOrder:= true  // fichier TIFF alignement Motorola
             else
                Exit;
      ExifOffset:= ReadLong;
      Position:= ExifOffset;
      FNbDirEntries:= ReadWord;
      FExifStart:= 0;
      Result:= (FNbDirEntries > 0);
      FIfd0Start:= Position; // départ des entrées de l'IFD0;
  end;
end;

function TExifFileStream.HasThumbNail(var ThumbStart, ThumbLen: cardinal): boolean;
var
  ExifTag: TExifTag;
  Ifd1: cardinal;
  I: integer;
  NbEntries: word;
begin
  Result:= false;
  ThumbStart:= 0;
  ThumbLen:= 0;
  try
     Position:= FIfd0Start + (FNbDirEntries * 12);
     Ifd1:= ReadLong; //on obtient l'offset de l'IFD1 (répertoire vignette)
     Position:= FExifStart + Ifd1;
     NbEntries:= ReadWord; // nombre d'entrées de l'IFD1
     for I:= 1 to NbEntries do
     begin
         ExifTag:= ReadTag;
         if ExifTag.Id = TagID_ThumbOffset then ThumbStart:= ExifTag.Offset;
         if ExifTag.Id = TagID_ThumbLen then ThumbLen:= ExifTag.Offset;
         if (ThumbStart > 0) and (ThumbLen > 0) then Break;
     end;
     if (ThumbStart > 0) and (ThumbLen > 0) then
     begin
         ThumbStart:= FExifStart + ThumbStart;
         Position:= ThumbStart;
         Result:= (ReadString(2) = #$FF#$D8); // la vignette est au format Jpeg
     end;
  except
  end;
end;

function TExifFileStream.GetThumbNail(ThumbStart, ThumbLen: cardinal; Bitmap: TBitmap): boolean;
var
  Jpeg: TJpegImage;
  Stream: TMemoryStream;
begin
  Result:= false;
  Stream:= TMemoryStream.Create;
  Jpeg:= TJpegImage.Create;
  try
      try
         Position:= ThumbStart;
         Stream.CopyFrom(Self, ThumbLen);
         Stream.Position:= 0;
         Jpeg.LoadFromStream(Stream);
         Bitmap.Assign(Jpeg);
         Result:= true;
      except
      end;
  finally
     Stream.Free;
     JPeg.Free;
  end;
end;

{TImageMetaData}

constructor TImageMetaData.Create;
begin
  inherited Create;
  // définition des Tags utilisés
  with TagsArray[0]  do begin Name:= 'description'; Id:= TagID_Description; Typ:= 2; Count:= 0; Dir:= 0; end;
  with TagsArray[1]  do begin Name:= 'fabricant'; Id:= TagID_Maker; Typ:= 2; Count:= 0; Dir:= 0; end;
  with TagsArray[2]  do begin Name:= 'modèle'; Id:= TagID_Model; Typ:= 2; Count:= 0; Dir:= 0; end;
  with TagsArray[3]  do begin Name:= 'date'; Id:= TagID_Date; Typ:= 2; Count:= 20; Dir:= 0; end;
  with TagsArray[4]  do begin Name:= 'vitesse'; Id:= TagID_Speed; Typ:= 5; Count:= 1; Dir:= 1; end;
  with TagsArray[5]  do begin Name:= 'ouverture'; Id:= TagID_Aperture; Typ:= 5; Count:= 1; Dir:= 1; end;
  with TagsArray[6]  do begin Name:= 'programme expo'; Id:= TagID_ExpoProgram; Typ:= 3; Count:= 1; Dir:= 1; end;
  with TagsArray[7]  do begin Name:= 'iso'; Id:= TagID_Iso; Typ:= 3; Count:= 1; Dir:= 1; end;
  with TagsArray[8]  do begin Name:= 'date original'; Id:= TagID_OriginalDate; Typ:= 2; Count:= 20; Dir:= 1; end;
  with TagsArray[9]  do begin Name:= 'mesure lumière'; Id:= TagID_MeteringMode; Typ:= 3; Count:= 1; Dir:= 1; end;
  with TagsArray[10] do begin Name:= 'focale'; Id:= TagID_Focal; Typ:= 5; Count:= 1; Dir:= 1; end;
  with TagsArray[11] do begin Name:= 'largeur'; Id:= TagID_ImageWidth; Typ:= 4; Count:= 1; Dir:= 1; end;
  with TagsArray[12] do begin Name:= 'hauteur'; Id:= TagID_ImageHeight; Typ:= 4; Count:= 1; Dir:= 1; end;
  with TagsArray[13] do begin Name:= 'balance des blancs'; Id:= TagID_WhiteBalance; Typ:= 3; Count:= 1; Dir:= 1; end;
  with TagsArray[14] do begin Name:= 'focale équivalent 35mm'; Id:= TagID_Focal35mm; Typ:= 3; Count:= 1; Dir:= 1; end;
  with TagsArray[15] do begin Name:= 'contraste'; Id:= TagID_Contrast; Typ:= 3; Count:= 1; Dir:= 1; end;
  with TagsArray[16] do begin Name:= 'saturation'; Id:= TagID_Saturation; Typ:= 3; Count:= 1; Dir:= 1; end;
  with TagsArray[17] do begin Name:= 'accentuation'; Id:= TagID_Sharpness; Typ:= 3; Count:= 1; Dir:= 1; end;
  // Tags concernant la vignette
  with TagThumb1 do begin Id:= $0100; Typ:= 4; Count:= 1; end; // largeur vignette
  with TagThumb2 do begin Id:= $0101; Typ:= 4; Count:= 1; end; // hauteur vignette
  with TagThumb3 do begin Id:= $0103; Typ:= 3; Count:= 1; end; //compression vignette
  with TagThumb4 do begin Id:= $0201; Typ:= 4; Count:= 1; end; // offset vers vignette
  with TagThumb5 do begin Id:= $0202; Typ:= 4; Count:= 1; end; // taille de la vignette
  with TagSubdir do begin Id:= $8769; Typ:= 4; Count:= 1; end; // Offset du sous-répertoire
  // initialisation des valeurs des Tags
  InitializeTags;
end;

procedure TImageMetaData.InitializeTags;
var
  I: integer;
begin
  for I:= 0 to High(TagsArray) do
    with TagsArray[I] do
    begin
      Value:= '';
      Value2:= '';
  end;
  TagThumb1.Offset:= 0;
  TagThumb2.Offset:= 0;
  TagThumb3.Offset:= 6; //compression vignette: 6= Jpeg
  TagThumb4.Offset:= 0;
  TagThumb5.Offset:= 0;
  TagSubdir.Offset:= 0;
end;

procedure TImageMetaData.ReadTagValues(ExifTag: TExifTag);
var
  I: integer;
  CurPos: Cardinal;
begin
  for I:= 0 to High(TagsArray) do
     if TagsArray[I].Id = ExifTag.Id then
     begin
         case TagsArray[I].Typ of
            2: begin
                   CurPos:= FFileStream.Position;
                   FFileStream.Position:= FFileStream.FExifStart + ExifTag.Offset;
                   TagsArray[I].Value:= FFileStream.ReadString(ExifTag.Count);
                   FFileStream.Position:= CurPos;
                end;
            3,4: TagsArray[I].Value:= ExifTag.Offset;
            5: begin
                   CurPos:= FFileStream.Position;
                   FFileStream.Position:= FFileStream.FExifStart + ExifTag.Offset;
                   TagsArray[I].Value:= FFileStream.ReadLong;
                   TagsArray[I].Value2:= FFileStream.ReadLong;
                   FFileStream.Position:= CurPos;
                end;
         end;
         Break;
     end;
end;

{lecture des données Exif
 la fonction peut être appelée avec ThumbNail = nil pour ne pas extraire la vignette}
function TImageMetaData.ReadExif(FileName: string; ThumbNail: TBitmap): boolean;
var
  Position: Cardinal;
  I,J: integer;
  ExifTag: TExifTag;
  SubDirEntries: word;
  ThumbStart, ThumbLen: cardinal;
begin
   Result:= false;
   InitializeTags;

   FFileStream:= TExifFileStream.Create(FileName, fmOpenRead);
   try
      try
         Result:= FFileStream.HasExif;
         if Result then
         begin
              for I:= 1 to FFileStream.FNbDirEntries do
              begin
                  ExifTag:= FFileStream.ReadTag;
                  if ExifTag.ID = TagID_SubDir then
                  begin
                      Position:= FFileStream.Position;
                      FFileStream.Position:= FFileStream.FExifStart + ExifTag.Offset;
                      SubDirEntries:= FFileStream.ReadWord;
                      for J:= 1 to SubDirEntries do
                      begin
                          ExifTag:= FFileStream.ReadTag;
                          ReadTagValues(ExifTag);
                      end;
                      FFileStream.Position:= Position;
                  end
                  else
                      ReadTagValues(ExifTag);
              end;
              if ThumbNail <> nil then
                 if FFileStream.HasThumbNail(ThumbStart, ThumbLen) then
                    FFileStream.GetThumbNail(ThumbStart, ThumbLen, ThumbNail);
         end;
      except
      end;
   finally
      FFileStream.Free;
   end;
end;

{Sauvegarde avec données exif
 Si ThumbMaxSize = 0 , la vignette ne sera pas incorporée}
function TImageMetaData.SaveToJpeg(Bitmap: TBitmap; FileName: string; ThumbMaxSize: integer): boolean;
const
  JpegHeader: array[0..19] of byte = ($FF,$D8,$FF,$E1,
                                      0,0,
                                      $45,$78,$69,$66,0,0,
                                      $49,$49,$2A,0,$08,0,0,0);
var
  F, ImageStream, ThumbStream: TMemoryStream;
  N: integer;
  DirEntries, SubDirEntries, LenExif: word;
  JpegImage: TJpegImage;
  Ifd1Offset: cardinal;
  BufLong: cardinal;
  DirValuesOffset: cardinal;
  SubDirOffset: cardinal;

        procedure WriteEntries(Dir: byte);
        var
          I: integer;
          ExifTag: TExifTag;
        begin
            for I:= 0 to High(TagsArray) do
               if (TagsArray[I].Dir = Dir) and (string(TagsArray[I].Value) <> '') then
               begin
                   ExifTag.Id:= TagsArray[I].Id;
                   ExifTag.Typ:= TagsArray[I].Typ;
                   ExifTag.Count:= TagsArray[I].Count;
                   case TagsArray[I].Typ of
                      2: begin
                            ExifTag.Count:= Length(string(TagsArray[I].Value));
                            ExifTag.Offset:= DirValuesOffset;
                            DirValuesOffset:= DirValuesOffset + ExifTag.Count;
                         end;
                      3,4: ExifTag.Offset:= Cardinal(TagsArray[I].Value);
                      5: begin
                            ExifTag.Offset:= DirValuesOffset;
                            DirValuesOffset:= DirValuesOffset + 8;
                         end;
                   end;
                   F.WriteBuffer(ExifTag, SizeOf(ExifTag));
               end;
        end;


        procedure WriteOffsetValues(Dir: byte); // valeurs placées en offset
        var
          I: integer;
          Buf: cardinal;
          S: string;
        begin
            for I:= 0 to High(TagsArray) do
                if (TagsArray[I].Dir = Dir) and (string(TagsArray[I].Value) <> '') then
                begin
                    case TagsArray[I].Typ of
                       2: begin
                             S:= string(TagsArray[I].Value);
                             F.WriteBuffer(S[1], Length(S));
                          end;
                       5: begin
                             Buf:= Cardinal(TagsArray[I].Value);
                             F.WriteBuffer(buf,4);
                             Buf:= Cardinal(TagsArray[I].Value2);
                             F.WriteBuffer(Buf,4);
                          end;
                    end;
                end;
        end;


        procedure MakeThumbNail;
        var
           ThumbBitmap: TBitmap;
           ThumbJpeg: TJpegImage;
           Percent: double;
        begin
           ThumbBitmap:= TBitmap.Create;
           ThumbJpeg:= TJpegImage.Create;
           ThumbStream:= TMemoryStream.Create;
           try
               Percent:= Min(ThumbMaxSize / Bitmap.Width, ThumbMaxSize / Bitmap.Height);
               with ThumbBitmap do
               begin
                   Width:=  Round(Bitmap.Width * Percent);
                   Height:= Round(Bitmap.Height * Percent);
                   PixelFormat:= Bitmap.PixelFormat;
               end;
               SetStretchBltMode(ThumbBitmap.Canvas.Handle, HALFTONE);
               StretchBlt(ThumbBitmap.Canvas.Handle,
                          0, 0, ThumbBitmap.Width, ThumbBitmap.Height,
                          Bitmap.Canvas.Handle,
                          0, 0, Bitmap.Width, Bitmap.Height,
                          SRCCOPY);
               ThumbJpeg.Assign(ThumbBitmap);
               ThumbJpeg.SaveToStream(ThumbStream);
               TagThumb1.Offset:= ThumbBitmap.Width;
               TagThumb2.Offset:= ThumbBitmap.Height;
               TagThumb5.Offset:= ThumbStream.Size;
           finally
               ThumbBitmap.Free;
               ThumbJpeg.Free;
           end;
        end;

begin
  Result:= false;
  ThumbStream:= nil;
  ImageStream:= TMemoryStream.Create;
  F:= TMemoryStream.Create;
  JpegImage:= TJpegImage.Create;

  try
     try
        if ThumbMaxSize > 0 then MakeThumbNail;
        //compte le nb d'entrées du répertoire IFD0 et du sous-répertoire éventuel
        DirEntries:= 0;
        SubDirEntries:= 0;
        SubDirOffset:= 0;
        for N:= 0 to High(TagsArray) do
           if string(TagsArray[N].Value) <> '' then
              if TagsArray[N].Dir = 0 then Inc(DirEntries) else Inc(SubDirEntries);
        if SubDirEntries > 0 then Inc(DirEntries);
        if DirEntries = 0 then  // il faut au moins une entrée
        begin
           SetDescription('  ' + #0);
           DirEntries:= 1;
        end;
        // écriture du header
        F.WriteBuffer(JpegHeader, sizeof(JpegHeader));
        // écriture du nombre d'entrées du répertoire IFD0
        F.WriteBuffer(DirEntries, 2);
        // calcul du départ des valeurs placées en offset
        DirValuesOffset:= 10 + (DirEntries * 12) + 4; // + 4 pcq on doit stocker le pointeur vers IFD1
        // écriture des entrées du répertoire principal IFD0
        WriteEntries(0);
        // écriture de l'entrée pointant sur le sous-répertoire
        // on mémorise sa position pour corriger par après l'offset
        if SubDirEntries > 0 then
        begin
           F.WriteBuffer(TagSubDir, sizeof(TagSubDir));
           SubDirOffset:= F.Position - 4;
        end;
        // écriture de l'offset de IFD1 (vignette)
        // on mémorise sa position pour corriger par après l'offset
        Ifd1Offset:= F.Position;
        BufLong:= 1;
        F.WriteBuffer(BufLong, 4);
        // écriture des valeurs placées en offset du répertoire principal
        WriteOffsetValues(0);
        // sous-répertoire de IFD0
        if SubDirEntries > 0 then
        begin
           // correction de l'offset du sous-répertoire
           BufLong:= F.Position - 12;
           F.Position:= SubDirOffset;
           F.WriteBuffer(BufLong, SizeOf(BufLong));
           F.Position:= BufLong + 12;
           // écriture du nb d'entrées du sous répertoire
           F.WriteBuffer(SubDirEntries,2);
           //calcul du départ des valeurs placées en offset
           DirValuesOffset:= F.Position - 12 + (SubDirEntries * 12);
           // écriture des entrées du sous-répertoire de IFD0
           WriteEntries(1);
           // écriture des valeurs placées en offset
           WriteOffsetValues(1);
        end;
        // IFD1 = répertoire vignette
        if ThumbMaxSize > 0 then
        begin
            // correction de l'offset du début d'IFD1
            BufLong:= F.Position-12;
            F.Position:= Ifd1Offset;
            F.WriteBuffer(BufLong, SizeOf(BufLong));
            F.Position:= BufLong + 12;
            // écriture du nombre d'entrées de l'IFD1
            DirEntries:= 5;
            F.WriteBuffer(DirEntries, SizeOf(DirEntries));
            // écriture des tags de IFD1
            F.WriteBuffer(TagThumb1, SizeOf(TagThumb1));
            F.WriteBuffer(TagThumb2, SizeOf(TagThumb2));
            F.WriteBuffer(TagThumb3, SizeOf(TagThumb3));
            TagThumb4.Offset:= F.Position + 12; //+12 = -12 (header) + 24: écriture des tagthumb 4 et 5
            F.WriteBuffer(TagThumb4, SizeOf(TagThumb4));
            F.WriteBuffer(TagThumb5, SizeOf(TagThumb5));
            // écriture de la vignette
            ThumbStream.Position:= 0;
            F.CopyFrom(ThumbStream, ThumbStream.Size);
        end;
        // On est à la fin de l'EXIF, on mémorise sa longeur
        LenExif:= SwapWord(F.Size - 2);
        // écriture de l'image principale
        JpegImage.Assign(Bitmap);
        JpegImage.SaveToStream(ImageStream);
        ImageStream.Position:= 0;
        F.CopyFrom(ImageStream, ImageStream.Size);
        // correction de la longueur de l'exif
        F.Position:= 4;
        F.WriteBuffer(LenExif, SizeOf(LenExif));
        // on n'a plus qu'à sauver le fichier
        F.SaveToFile(FileName);
        Result:= true;
     except
     end;
  finally
     if ThumbStream <> nil then ThumbStream.Free;
     JpegImage.Free;
     ImageStream.Free;
     F.Free;
  end;
end;

{affiche les données Exif dans un TMemo}
procedure TImageMetaData.DisplayTags(Memo: TMemo);
var
  I: integer;
  D: double;
  S: string;
begin
  try
     Memo.Clear;
     for I:= 0 to High(TagsArray) do
       if string(TagsArray[I].Value) <> '' then
       begin
           S:= '';
           case TagsArray[I].Id of
              TagID_ExpoProgram: case Cardinal(TagsArray[I].Value) of
                                    1: S:= 'manuel';
                                    2: S:= 'normal';
                                    3: S:= 'priorité ouverture';
                                    4: S:= 'priorité vitesse';
                                    7: S:= 'mode portrait';
                                    8: S:= 'mode paysage';
                                    else S:= 'inconnu';
                                  end;
              TagID_MeteringMode: case Cardinal(TagsArray[I].Value) of
                                    1: S:= 'moyenne';
                                    2: S:= 'moyenne avec prépondérance au centre';
                                    3: S:= 'spot';
                                    4: S:= 'multispot';
                                    5: S:= 'matricielle';
                                    6: S:= 'partielle';
                                    else S:= 'inconnu';
                                  end;
                     TagID_Speed: S:= IntToStr(TagsArray[I].Value) +
                                      '/' + IntToStr(TagsArray[I].Value2);
                TagID_WhiteBalance: if Cardinal(TagsArray[I].Value) = 0 then S:= 'auto' else S:= 'manuelle';
                 TagID_Contrast,
               TagID_Saturation,
                TagID_Sharpness: case Cardinal(TagsArray[I].Value) of
                                   0: S:= 'normal';
                                   1: S:= 'adouci';
                                   2: S:= 'renforcé';
                                 end;
           end;
           if S = '' then
              case TagsArray[I].Typ of
                  2: S:= string(TagsArray[I].Value);
                3,4: S:= IntToStr(cardinal(TagsArray[I].Value));
                  5: begin
                        D:= cardinal(TagsArray[I].Value) / cardinal(TagsArray[I].Value2);
                        S:= FloatToStr(D);
                     end;
              end;
           S:= TagsArray[I].Name + ': ' + S;
           Memo.Lines.Add(S);
       end;
  except
  end;
end;

procedure TImageMetaData.GetExifTag(TagID: word; var Value1, Value2: variant);
var
  I: integer;
begin
  Value1:= '';
  Value2:= '';
  for I:= 0 to High(TagsArray) do
     if TagsArray[I].Id = TagID then
     begin
       Value1:= TagsArray[I].Value;
       Value2:= TagsArray[I].Value2;
       Break;
     end;
end;

procedure TImageMetaData.SetExifTag(TagID: word; Value1, Value2: variant);
var
  I: integer;
  S: string;
begin
  for I:= 0 to High(TagsArray) do
     if TagsArray[I].Id = TagID then
       case TagsArray[I].Typ of
          2: begin
               S:= String(Value1);
               if (S <> '') and (S[Length(S)] <> #0) then S:= S + #0;
               TagsArray[I].Value:= S;
             end;
         else
         begin
           TagsArray[I].Value:= Value1;
           TagsArray[I].Value2:= Value2;
         end;
        Break;
     end;
end;

procedure TImageMetaData.SetDescription(Value: string);
begin
   SetExifTag(TagID_Description, Value, '');
end;

end.
