import os
import webloc

links = []
for i in os.listdir('links'):
	link = webloc.read(f'links/{i}')
	txt = i.replace('.webloc','')
	links.append((txt, link))

links = sorted(links)
with open('links.md','w') as f:
	for txt, link in links:
		f.write(f"- [{txt}]({link})\n")
		f.write('\n')



