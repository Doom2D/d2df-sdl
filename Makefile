all:
	cd "Game Source"; fpc -MDELPHI -gw -O2 -FE../Bin -FU../Temp Doom2DF.dpr

clean:
	rm -rf Temp/*
