target = bytearray(b'\x00' + b'12312312091205iwejoweifjwiefjwoefjwoefjpowifjpowifjpoiejpiojwpiojgiojgiosjgepijgspijgpiojgpijgpiogjpijgpiosjgisjgpisjreijsrgojgposeijgposijgspiogjspoigjpoirgjirjgoigjpoijgpiorjg91', 'latin-1')
xor = b'woicjapowijcpowijcapoijcawoejcapoeijcpoijcpoijcoiwjcepoijcpoijcopwijcpowijcpioejcijcpioeji'

for _ in range(10000000):
    target = bytearray(x ^ y for x, y in zip(target, xor))

print(chr(target[0]))
