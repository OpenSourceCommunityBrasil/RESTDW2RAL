object fprincipal: Tfprincipal
  Left = 0
  Top = 0
  Caption = 'rdw2ral - conversor de projetos REST Dataware'
  ClientHeight = 601
  ClientWidth = 894
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object spl: TSplitter
    Left = 0
    Top = 361
    Width = 894
    Height = 5
    Cursor = crVSplit
    Align = alBottom
    ExplicitTop = 300
  end
  object pnTopo: TPanel
    Left = 0
    Top = 0
    Width = 894
    Height = 122
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lbPasta: TLabel
      Left = 12
      Top = 12
      Width = 348
      Height = 15
      Caption =
        'Pasta do projeto a converter (ou arraste a pasta para esta janela' +
        '):'
    end
    object edPasta: TEdit
      Left = 12
      Top = 33
      Width = 745
      Height = 23
      TabOrder = 0
      OnChange = edPastaChange
    end
    object btEscolher: TButton
      Left = 763
      Top = 32
      Width = 119
      Height = 25
      Caption = 'Escolher pasta...'
      TabOrder = 1
      OnClick = btEscolherClick
    end
    object chkBackup: TCheckBox
      Left = 14
      Top = 68
      Width = 200
      Height = 17
      Caption = 'Guardar o original como .bak'
      Checked = True
      State = cbChecked
      TabOrder = 2
    end
    object lbServidor: TLabel
      Left = 14
      Top = 90
      Width = 118
      Height = 15
      Caption = 'Servidor do RAL a gerar:'
    end
    object cbServidor: TComboBox
      Left = 138
      Top = 86
      Width = 260
      Height = 23
      Style = csDropDownList
      TabOrder = 6
    end
    object chkTipos: TCheckBox
      Left = 224
      Top = 68
      Width = 400
      Height = 17
      Caption =
        'Trocar tambem os tipos de nome generico (TDataMode, TObjectValue...)'
      TabOrder = 3
    end
    object btSimular: TButton
      Left = 645
      Top = 64
      Width = 112
      Height = 27
      Caption = '1. Simular'
      Default = True
      TabOrder = 4
      OnClick = btSimularClick
    end
    object btAplicar: TButton
      Left = 763
      Top = 64
      Width = 119
      Height = 27
      Caption = '2. Aplicar'
      TabOrder = 5
      OnClick = btAplicarClick
    end
  end
  object pnCima: TPanel
    Left = 0
    Top = 122
    Width = 894
    Height = 239
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lbArquivos: TLabel
      Left = 0
      Top = 0
      Width = 894
      Height = 19
      Align = alTop
      Caption = '  Arquivos que mudam (duplo clique abre a pasta)'
      Layout = tlCenter
      ExplicitWidth = 246
    end
    object lvArquivos: TListView
      Left = 0
      Top = 19
      Width = 894
      Height = 241
      Align = alClient
      Columns = <
        item
          Caption = 'Arquivo'
          Width = 260
        end
        item
          Alignment = taRightJustify
          Caption = 'Alteracoes'
          Width = 80
        end
        item
          Caption = 'Pasta'
          Width = 520
        end>
      GridLines = True
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnDblClick = lvArquivosDblClick
    end
  end
  object pnBaixo: TPanel
    Left = 0
    Top = 366
    Width = 894
    Height = 216
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object lbAvisos: TLabel
      Left = 0
      Top = 0
      Width = 894
      Height = 19
      Align = alTop
      Caption = '  Avisos'
      Layout = tlCenter
      ExplicitWidth = 44
    end
    object mAvisos: TMemo
      Left = 0
      Top = 19
      Width = 894
      Height = 197
      Align = alClient
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 0
    end
  end
  object sb: TStatusBar
    Left = 0
    Top = 582
    Width = 894
    Height = 19
    Panels = <>
    SimplePanel = True
  end
end
