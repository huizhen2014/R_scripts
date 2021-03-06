##Gene Co-expresion Network Analysis 
##unweighted networks using hard thresholding 
##weighted networks using soft thresholding

##nodes 代表基因，若在恰当的组织样本中对应的基因共表达，则这些nodes会连接起来
##adjacency matrix/相邻矩阵 networks; A=[aij] 为对称矩阵，A值位于[0,1],传统而言，对角线值为0
##对于unweighted networkds,相邻矩阵包含binary信息,相连为1，不相连为0;
##在weighted networks中，相邻矩阵包含weights.

##该tutuorial data来自yeast microarray data set
##预测酵母生存必须基因,若这些基因紧密相连，则倾向于为必须基因，为1，否则为0
##简而言之，基因的显著性为任何定量检测判断该基因的生物显著性程度，network分析的
##一个目的就是关联基因显著性(必要程度)的测量值和内部模型的联系.

##模型构建
##将共表达的一组基因构建成一模型，一般使用average linkage hierachical clustering
##该方法使用topological overlap测量计算dissimilarity
##两个nodes的topological overlap反应了它们连接节点范围的相似性(the topological
##overlap of two nodes reflects their similarity in terms to the commonality
##of the nodes they connect to)
##当通过hierarchical clustering method获得dendrogram时，我们需要选择一高度阈值
##来实现clustering, 该阈值用于cut the branches.
##高度阈值(height cutoff)的选择可通过检测dendrogram中的一些branches对应
##离散度digonal blocks(modules) in the TOM plot. 一般推荐使用cutreeDynamic
##用于brance cuting
##这里采用静态(fixed) cutree method


library(WGCNA)
options(stringsAsFactors=F)
dat0 <- read.csv("YEASTCellCycle4000.csv",header=T,row.names=1)
##gene exprssion data: 行为array(样本),列为基因
datExpr <- t(dat0)
##数据信息，其中essentiality列指明该基因是否对于酵母生存必须
datSummary <- read.csv("YEASTCellCycle4000.csv",header=T,row.names=1)

##限制分析范围为变化最大的基因
var1 <- function(x)var(x,na.rm=T)
vargenes <- apply(datExpr,2,var1)
rankvar <- rank(-vargenes)
restVariance <- rankvar < 4001 ##这里保留所有基因
datExpr <- datExpr[,restVariance]
datSummary <- datSummary[restVariance,]

##使用scale-free topology creterion 来选择cutoff值
##使用线性回归模型fitting index来评估network满足
##scale-free topology的程度

##针对不同的soft thresoholds(powers) 构建scale free
##topology fitting indices, 用于挑选soft threshold
powers1 <- c(seq(1,10,by=1),seq(12,20,by=2))
RpowerTable <- pickSoftThreshold(datExpr,powerVector = powers1)[[2]]

cex1=1
par(mfrow=c(1,2))
plot(RpowerTable[,1],-sign(RpowerTable[,3])*RpowerTable[,2],
     xlab="Soft Threshold(power)", ylab="Scale Free Topology Model Fit, signed R^2",
     type="n")
text(RpowerTable[,1],-sign(RpowerTable[,3])*RpowerTable[,2],
                           labels=powers1,cex=cex1,col="red")
#This line correspond to using an R^2 cutoff of h
abline(h=0.85,col="red")
plot(RpowerTable[,1],RpowerTable[,5],xlab="Soft Threshold(power)",
     ylab="Mean Connectivity",type="n")
text(RpowerTable[,1],RpowerTable[,5],labels=powers1,cex=cex1,col="red")

##at power=7, the 拟合曲线的R^2值出现拐点，也就是随着power的增加，
##scale free topology不在提高，因此选择beta1=7
##该过程通过最大化sacle free topology model fit(R^2),维持了高的
##平均连接数目，同时参数值导致R^2接近1也可能带来具有非常少连接的networks
##由于生物学上而言，相比于没有hub genes，networks不太可能拥有多个hubs gene
##we multiply R^2 with -1 if the slop of the regression line between 
##log_{10}(p(k))and log_{10}(k)is positive

##使用该power用于power adjacency function
beta1 < -7
Connectivity <- softConnectivity(datExpr,power=beta1)
##构建scale free topology，黑曲线对应scale free topology
##红曲线对应 truncated scale free topology
par(mfrow=c(1,1))
scaleFreePlot(Connectivity,main=paste("soft threshold, power",beta1),truncated=T)

##检出模型
##network 分析最重要的一个步骤就是module detection
##这里使用clustering in combination with the topological overlap matrix

##该代码限制分析最关联的基因，这在模型检测过程中可加快计算速度
ConnectivityCut <- 2001 #考虑迭代最关联的基因数目范围
ConnectivityRank <- rank(-Connectivity)
restConnectivity <- ConnectivityRank <= ConnectivityCut
##因此使用剩下基因检出模型
sum(restConnectivity) #2001
##限制相邻矩阵为最关联基因,前2001个基因
ADJrest <- adjacency(datExpr[,restConnectivity],power=beta1)
##根据相邻矩阵，计算topological overlap matrix
dissTOM <- TOMdist(ADJrest) ##计算为1- TOMsimmilarity()

##现在是根据TOM matrix获得hierarchical clustering.
##clustering tree的分支用于定义基因模型
##Hierarchical cluster analysis on a set of
##dissimilarities and methods for analyzing it.
hierTOM <- hclust(as.dist(dissTOM),method="average")
par(mfrow=c(1,1))
plot(hierTOM,labels=F,sub="",xlab="")
##根据定义，moduls对应tree的一个一个分支
##问题是，使用什么样的hieght cut-off. 大的
##height values导致大的moduls，小的带来小且
##紧的模型，实际中，我们使用不同的阈值来检测
##结果的稳定性
##函数cutreeSatticColor根据height cutoff对分支基因着色
##着灰色的基因表示不属于任何一个模型,我们仅考虑包含至少125个基因
##的模型
##Module detection in hierarchical dendrograms using a constant-height tree cut.
## Only branches whose size is at least minSize are retained.
colorh1 <- cutreeStaticColor(hierTOM,cutHeight = 0.97)
table(colorh1)

par(mfrow=c(2,1),mar=c(2,4,2,2))
plot(hierTOM,main="",labels=F,xlab="",sub="")
plotColorUnderTree(hierTOM,colors=
                     data.frame(colorh1,Essentiality=
                                  GeneSignificance))
##色块对应模型的大小，table(colorh1)对应模型大小及颜色
##Essentiality的色带表明是否该该基因为必须基因(黑色为必须，
##白色为非必须)
##最小的模型大小由cutreeStaticColors函数的minSize参数指定，
##默认值为minSize=50
##这里使用的固定hight cutoff，可使用动态tree cuting算法
##cutreeDynamic

##另一个查看方式为TOM plot，由函数TOMplot完成
TOMplot(dissTOM,hierTOM,colorh1,terrainColors = T)
##改图中，行和列都对应基因，模型对应为沿对角线的方块

##经典的多维度scaling plot查看networks
##这里选取3个维度
cmd1 <- cmdscale(as.dist(dissTOM),3)
pairs(cmd1,col=as.character(colorh1),main="MDS plot")

##3D plot of the same scaling coordinates
par(mfrow=c(1,1),mar=c(4,3,2,3)+0.1)
library(scatterplot3d)
scatterplot3d(cmd1,color=colorh1,angle=250,
              xlab="Scaling Axis 1",ylab="Scaling Axis 2",
              zlab="Scaling Axis 3")

##函数verboseBarplot绘制条形图，该图显示该模型是否针对
##essential genes富集，同时也报告Kruskal Wallis P-value
##基因的显著性可以是二进制变量，或一个定量的变量，同时
##绘制均值的95%的致信区间
par(mfrow=c(1,1))
verboseBarplot(GeneSignificance,colorh1,main="Module Significance",
               col=levels(factor(colorh1)),xlab="Module")
##可见一个模型和essential genes高度富集

##通过summarize每一module的第一该eigengene(principal components),
##可得知模型之间的关系，然后根据相互之间关系修正这些模型的eigengenes
##Calculates module eigengenes (1st principal component) of modules
##in a given single dataset.
datME <- moduleEigengenes(datExpr[,restConnectivity],colorh1)

##在模型的eigengenes之间定义一个差异测量，来追溯模型egiengenes
##关系的信号,1减去相关性得到差异性
dissimME <- 1-(t(cor(datME$eigengenes,method="p")))/2

hclustdatME <- hclust(dist(dissimME),method="average")
par(mfrow=c(1,1))
plot(hclustdatME,main="Clustering tree based on the 
     module eigengenes of modules")

##根据模型的eigengenes构建scatter plots
pairs(datME$eigengenes)

##比较成对图之间eigengenes的相关性
signif(cor(datME$eigengenes,use="p"),2)
##不同模型的eigengenes(first PC)可能高度相关
##WGCNA可被解释为biologically motivated data reduction scheme
##允许最终成分之间的依赖性。将这和主成分析比较能够在不同成分
##间加入正交性质
##由于模型可能代表了生物信号通路，但是没有生物学原因解释为何模型
##应该互相正交。
##Langfelder P, Horvath S (2007) Eigengene networks for studying the 
##relationships between co- expression modules. BMC Systems Biology 2007, 1:54

##探究平均基因表达或基因表达变异和connectivity之间的关联程度
mean1 <- function(x)mean(x,na.rm=T)
var1 <- function(x)var(x,na.rm=T)
meanExpr <- apply(datExpr[,restConnectivity],2,mean1)
varExpr <- apply(datExpr[,restConnectivity],2,var1)
par(mfrow=c(1,2))
plot(Connectivity[restConnectivity],meanExpr,col=colorh1,main="Mean(Expression) vs K")
plot(Connectivity[restConnectivity],varExpr,col=colorh1,main="Var(Expression) vs K")

##plot heatmap for each module
##行为基因，列为样本, 模型定义的越好，出现的带状结构约明显，因为其对应基因
##高度相关
par(mfrow=c(2,1),mar=c(1,2,4,1))
ClusterSamples <- hclust(dist(datExpr[,restConnectivity]),method="average")
##第一个模型(turquoise)
which.module="turquoise"
plotMat(t(scale(datExpr[ClusterSamples$order,restConnectivity][,colorh1==which.module])),
         nrgcols=30,rlabels=T,clabels=T,rcols=which.module,main=which.module)
##第二个模型(蓝色)
which.module="blue"
plotMat(t(scale(datExpr[ClusterSamples$order,restConnectivity][,colorh1==which.module])),
           nrgcols=30,rlabels=T,clabels=T,rcols=which.module,main=which.module)

##每一个模型都应该有一个清晰的带状结构。对应每一个列，都应为相同颜色。白色的带表缺失值。

##针对所有基因定义非module基因为灰色
color1 <- rep("grey",sum(restVariance))
color1[restConnectivity]=as.character(colorh1)

##计算所有cluster的变异系数
##cluster的系数用来测量基因所属小集团
CC <- clusterCoef(ADJrest)

##针对所有的基因的关联性绘制cluster 系数图
par(mfrow=c(1,1))
plot(Connectivity[restConnectivity],CC,col=as.character(colorh1),
     xlab="Connectivity",ylab="Cluster Coefficient")
##随着Connectivity增加，图中不同cluster逐渐分开

##计算模型内的cluster系数和connectivity之间的相关性
####A data frame is split by row into data frames 
##subsetted by the values of one or more factors, 
##and function FUN is applied to each subset in turn.
by(data.frame(CC=CC,k=Connectivity[restConnectivity]),INDICES=colorh1,FUN=cor)
##大部分module中，k和CC存在正相关性


##Construction and unweighted network with HARD THRESHOLDING
##根据表达数据，计算每基因对表达之间对绝对相关(person)系数。然后网络的每一个
##节点带表一个基因。如果两个节点的相关系数超过阈值0.7，那么两个节点之间的就
##会存在一个edge。该阈值是通过scale free criterion获得。
##构建unweighted network(hard thresholding)，考虑下面潜在阈值向量

thresholds1 <- c(seq(.1,.5,by=.1),seq(.55,.9,by=0.05))

##使用scale-free Topology标准来选择cutoff value。这里着重与线性回归模型匹配index
##(scale.law.R.2)，量化network满足scale-free topoloty的程度
##在step adjacency函数中使用函数PickHardThreshold评估cutoff vlaue
RdichotTable <- pickHardThreshold(datExpr,cutVector = thresholds1)[[2]]
##hard threshold(cut)标准：high scale free R^2(列3),high connectivity(列6)
##negative slop(列4，-1左右)
##根据结果,行对应样本，列对应基因
RdichotTable <- pickHardThreshold(datExpr,cutVector = thresholds1)[[2]]
##绘制scale free topology model fitting index(R^2) versus cut-off tau
cex1 <- 0.7
par(mfrow=c(1,2))
plot(RdichotTable[,1],-sign(RdichotTable[,4])*RdichotTable[,3],
     xlab="Hard Threshold tau",ylab="Scale Free Topology Model Fit,
     signed R^2",type="n")
text(RdichotTable[,1],-sign(RdichotTable[,4])*RdichotTable[,3],labels=
       thresholds1,cex=cex1)
abline(h=0.85,col="red")
plot(RdichotTable[,1],RdichotTable[,6],xlab="Hard Threshold tau",
     ylab="Mean Connectivity",type="n")
text(RdichotTable[,1],RdichotTable[,6],labels=thresholds1,cex=cex1)
##图中可见，slop值在-1附近，平均连接数目合理地高34.5, 选择cut=0.65

##采用tau=0.65 进行unweighted networkds分析
##I Change the class of an object to indicate that it should be treated ‘as is’.
ADJhardrest <- I(abs(cor(datExpr[,restConnectivity],use="p"))>0.65)+0.0

##根据相邻矩阵计算topological overlap matrix
dissTOM2 <- TOMdist(ADJhardrest)

##根据TOM matrix构建hierarchical clustering，根据clustering
##tree的分支(branches)定义基因模块
hierGTOM2 <- hclust(as.dist(dissTOM2),method="average")
par(mfrow=c(1,1))
plot(hierGTOM2,labels=F)

##根据定义，模块对应tree的分支，函数modulecolor2用于依靠高度阈值，
##根据分支对基因着色。灰色为保留颜色，表示不属于任何一个分支
##Cluster detection by a constant height cut of a hierarchical
##clustering dendrogram.
colorh2 <- cutreeStaticColor(hierGTOM2,cutHeight = 0.75)

table(colorh2,colorh1)

par(mfrow=c(5,1),mar=c(2,2,2,1))
plot(hierTOM,main="Soft TOM Measure",labels=F,xlab="",sub="")
plot(hierGTOM2,main="Hard TOM Measure",labels=F,xlab="",sub="")
plotColorUnderTree(hierTOM,colors=colorh1)
title('Colored by soft modules')
plotColorUnderTree(hierTOM,colorh2)
title('Colored by hard modules')
plotColorUnderTree(hierTOM,GeneSignificance)
title('Colored by essentiality')
##图中可见hard和soft阈值下的模型处于高度保守状态
##或采用函数TOMplot查看
##输入，TOM distance measure, hierarchical(hclust) object, color
TOMplot(dissTOM2,hierGTOM2,colorh1)

##查看针对不同的hard threshold，k Within and genes significance 相关性
##在truquoise模型中的变化
corhelp <- cor(datExpr[,restConnectivity],use="pairwise.complete.obs")
whichmodule <- "turquoise"
##接下来的数据框包含了对应不同hard thresholds的模型内部连接性
datconnectivitiesHard <- data.frame(matrix(666,nrow=sum(color1==whichmodule),
                                           ncol=length(thresholds1)))
names(datconnectivitiesHard) <- paste("kWithinTau",thresholds1,sep="")
##模块间基因之间相关性
for(i in c(1:length(thresholds1))){
  datconnectivitiesHard[,i]=apply(abs(corhelp[colorh1==whichmodule,
                                              colorh1==whichmodule])>
                                    thresholds1[i],1,sum)
}
SpearmanCorrelationsHard <- signif(cor(GeneSignificance[colorh1==
                                                         whichmodule],
                                      datconnectivitiesHard,method="s",
                                      use="p"))

##在预测turquoise模块时，比较不同的hard阈值条件下，connectivity measures k
par(mfrow=c(1,1),mar=c(5,4,4,2)+0.1)
plot(thresholds1, SpearmanCorrelationsHard, main="
Cor(Connectivity,Gene Significance) vs Hard Thresholds",
     ylab="Spearman Correlation(Gene Significance,Connectivity)",
     xlab="Threshold tau", type="n", 
     ylim=range(c(SpearmanCorrelationsHard),na.rm=T))
text(thresholds1,SpearmanCorrelationsHard,labels=thresholds1,col="black")
##在tau处绘制垂线
abline(v=0.65,col='red')

##查看针对不同的soft thresholds(powers)，查看kWithin和gene
##essentiality changes之间的相关性, 限制为turquoise模块基因
par(mfrow=c(1,1))
datconnectivitiesSoft <- data.frame(matrix(666,nrow=sum(
  colorh1==whichmodule),ncol=length(powers1)))
names(datconnectivitiesSoft) <- paste("kWithinPower",powers1,sep="")
for(i in c(1:length(powers1))){
  datconnectivitiesSoft[,i]=apply(abs(corhelp[colorh1==whichmodule,
                                              colorh1==whichmodule])^powers1[i],1,sum)
}
SpearmanCorrelationsSoft <- signif(cor(GeneSignificance[colorh1==whichmodule],
                                       datconnectivitiesSoft,method="s",use="p"))

plot(powers1, SpearmanCorrelationsSoft, 
     main="Cor(Connectivity,Gene Significance) vs Soft Thresholds (powers)",
     ylab="Spearman Correlation(Gene Significance,k.in)",
     xlab="Power beta",type="n",
     ylim=range(c(SpearmanCorrelationsSoft),na.rm=T)
)
text(powers1,SpearmanCorrelationsSoft,labels=powers1,col="red")
abline(v=7,col="red")
##过高和过低的值均会减少biological signal




















