
bg_col="white"
font_col="black"
sat=0

png("Brujula3.png",width = 2000,height = 2000,res = 300)
par(mar=c(0,0,0,0), mai=c(0,0,0,0), bg=bg_col)
plot(c(-1,1)*1.5,c(-1,1)*1.5, xaxs="i", yaxs="i", axes=FALSE, frame.plot=FALSE, ann=FALSE, asp=1, type="n")
for(ang in seq(0,2,length.out=10001)) {
cols=hsv(h=2*ang-floor(2*ang),s = sat)
cols=adjust_brightness(c(cols,cols,cols,cols),rev((c(190,154,117,81))/255))
segments(c(0,0.25,0.50,0.75)*cos(ang*pi),
         c(0,0.25,0.50,0.75)*sin(ang*pi),
         c(0.25,0.5,0.75,1)*cos(ang*pi),
         c(0.25,0.5,0.75,1)*sin(ang*pi),col = cols,lwd=2)
}
arrows(c(0,0,0,0),c(0,0,0,0),c(1,0,-1,0)*1.15,c(0,1,0,-1)*1.15,lwd=2,col=font_col)
text(c(1,0,-1,0)*1.25,c(0,1,0,-1)*1.25,labels = c("E","N","O","S"),cex=1.5,col=font_col)

text(0.125,0,labels="Calles Primario",srt=90,col=font_col,adj=-0.01)
text(0.125+0.25,0,labels="Calles Secundario",srt=90,col=font_col,adj=-0.01)
text(0.125+0.25*2,0,labels="Calles Terciario",srt=90,col=font_col,adj=-0.01)
text(0.125+0.25*3,0,labels="Calles Residencial",srt=90,col=font_col,adj=-0.01)
dev.off()
file.show("Brujula3.png")
