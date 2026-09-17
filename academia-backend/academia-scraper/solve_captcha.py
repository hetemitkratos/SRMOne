import ddddocr, sys

if len(sys.argv) < 2:
    print("ERROR: usage: solve_captcha.py <image_path>")
    sys.exit(1)

o = ddddocr.DdddOcr(show_ad=False)
r = o.classification(open(sys.argv[1], 'rb').read())
print(r)
