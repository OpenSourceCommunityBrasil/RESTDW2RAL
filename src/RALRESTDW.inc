{ Sem diretivas.

  Havia aqui o RDW143, que escolhia a forma do handler de evento entre a do RDW
  2.x e a do 1.4.3. Era uma escolha por pacote instalado: trocar obrigava a
  recompilar tudo e quebrava todo DFM ja ligado.

  As duas formas passaram a ser publicadas ao mesmo tempo, com nomes diferentes
  (OnReplyEvent e OnReplyEventStr), e e o conversor quem aponta o DFM para a
  certa - ver RALRESTDWEvents. Um pacote so atende as duas geracoes.

  O arquivo fica porque as units o incluem e porque e aqui que entra a proxima
  diretiva, se houver. }
