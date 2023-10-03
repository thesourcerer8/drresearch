
int main()
{
  char target[476]="\00012312312091205iwejoweifjwiefjwoefjwoefjpowifjpowifjpoiejpiojwpiojgiojgiosjgepijgspijgpiojgpijgpiogjpijgpiosjgisjgpisjreijsrgojgposeijgposijgspiogjspoigjpoirgjirjgoigjpoijgpiorjg91";

  char xor[476]="woicjapowijcpowijcapoijcawoejcapoeijcpoijcpoijcoiwjcepoijcpoijcopwijcpowijcpioejcijcpioeji";
  int i;
  for(i=1;i<10000000;i++)
  {
    for(int j=0;j<476;j++)
    {	    
      target[j]^=xor[j];
    }
  }
  return(target[0]);
}
