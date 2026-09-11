object fprincipal: Tfprincipal
  Left = 0
  Top = 0
  Caption = 'fprincipal'
  ClientHeight = 299
  ClientWidth = 635
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object server: TRALSynopseServer
    Active = False
    CompressType = ctNone
    CookieLife = 30
    CORSOptions.AllowHeaders.Strings = (
      'Content-Type'
      'Origin'
      'Accept'
      'Authorization'
      'Content-Encoding'
      'Accept-Encoding')
    CORSOptions.AllowOrigin = '*'
    CORSOptions.MaxAge = 86400
    CriptoOptions.CriptType = crNone
    IPConfig.IPv4Bind = '0.0.0.0'
    IPConfig.IPv6Bind = '::'
    IPConfig.IPv6Enabled = False
    ResponsePages = <
      item
        StatusCode = 400
        Page.Strings = (
          
            '<!DOCTYPE html><html lang="en-US"><head><title>RALServer - 0.9.1' +
            '0-4 alpha</title></head><body><h1>400 - BadRequest</h1><p>The se' +
            'rver informs that it doesn'#39't like the input params</p></body></h' +
            'tml>')
      end
      item
        StatusCode = 401
        Page.Strings = (
          
            '<!DOCTYPE html><html lang="en-US"><head><title>RALServer - 0.9.1' +
            '0-4 alpha</title></head><body><h1>401 - Unauthorized</h1><p>The ' +
            'server informs that it doesn'#39't know you</p></body></html>')
      end
      item
        StatusCode = 403
        Page.Strings = (
          
            '<!DOCTYPE html><html lang="en-US"><head><title>RALServer - 0.9.1' +
            '0-4 alpha</title></head><body><h1>403 - Forbidden</h1><p>The ser' +
            'ver informs that it doesn'#39't want you to access</p></body></html>')
      end
      item
        StatusCode = 404
        Page.Strings = (
          
            '<!DOCTYPE html><html lang="en-US"><head><title>RALServer - 0.9.1' +
            '0-4 alpha</title></head><body><h1>404 - Not Found</h1><p>The ser' +
            'ver informs that the page you'#39're requesting doesn'#39't exist in thi' +
            's reality</p></body></html>')
      end
      item
        StatusCode = 415
        Page.Strings = (
          
            '<!DOCTYPE html><html lang="en-US"><head><title>RALServer - 0.9.1' +
            '0-4 alpha</title></head><body><h1>415 - Unsuported Media Type</h' +
            '1><p>The server informs that it doesn'#39't know what you'#39're asking<' +
            '/p></body></html>')
      end
      item
        StatusCode = 500
        Page.Strings = (
          
            '<!DOCTYPE html><html lang="en-US"><head><title>RALServer - 0.9.1' +
            '0-4 alpha</title></head><body><h1>500 - Internal Server Error</h' +
            '1><p>The server made something that it shouldn'#39't</p></body></htm' +
            'l>')
      end
      item
        StatusCode = 501
        Page.Strings = (
          
            '<!DOCTYPE html><html lang="en-US"><head><title>RALServer - 0.9.1' +
            '0-4 alpha</title></head><body><h1>501 - Not Implemented</h1><p>T' +
            'he server informs that it doesn'#39't exist</p></body></html>')
      end
      item
        StatusCode = 503
        Page.Strings = (
          
            '<!DOCTYPE html><html lang="en-US"><head><title>RALServer - 0.9.1' +
            '0-4 alpha</title></head><body><h1>503 - Service Unavailable</h1>' +
            '<p>The server informs that it doesn'#39't want to work now and you s' +
            'hould try later</p></body></html>')
      end>
    Port = 8000
    Routes = <>
    Security.BruteForce.ExpirationTime = 1800000
    Security.BruteForce.MaxTry = 3
    Security.FloodTimeInterval = 30
    Security.Options = []
    ShowServerStatus = True
    PoolCount = 32
    QueueSize = 1000
    SSL.Enabled = False
    Left = 336
    Top = 104
  end
  object rdw: TRALRESTDWModule
    Server = server
    Domain = '/'
    ClassModule = 'Tdm_restdw'
    Routes = <
      item
        InputParams = <>
        Route = '/ping'
        AllowedMethods = [amGET, amPOST, amOPTIONS]
        AllowURIParams = False
        Callback = False
        Name = 'ping'
        SkipAuthMethods = []
        URIParams = <>
      end>
    Left = 336
    Top = 168
  end
end
