unit uprincipal;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  RALRESTDWClientEvents, RALIndyClient, RALParams, RALTools, RALTypes,
  RALRESTDWParams, RALRESTDWTypes;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    cliente: TRALIndyClient;
    ce: TRALRESTDWClientEvents;
    OpenDialog1: TOpenDialog;
    procedure Button1Click(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
var
  dwparam : TRALRESTDWParams;
  vErro : StringRAL;
begin
  ce.CreateDWParams('ping', dwparam);
  dwparam.ItemsString['nome'].AsString := 'fernando';
  dwparam.ItemsString['valor'].AsFloat := 1.5;

  if ce.SendEvent('ping', dwparam, vErro) then begin
    ShowMessage(dwparam.ItemsString[cUndefined].AsString);
    ShowMessage(dwparam.ItemsString['nome'].AsString);
    ShowMessage(dwparam.ItemsString['valor'].AsString);
  end;
end;

end.

