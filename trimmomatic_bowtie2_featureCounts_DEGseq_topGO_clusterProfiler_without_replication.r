###part 1
##trimmomatic
#trimmomatic PE -summary kp_21_trimmed.log kp_21_R1.fastq.gz kp_21_R2.fastq.gz -baseout kp_21_trimmed.fastq.gz \
#ILLUMINACLIP:Sabgon_adapter.fa:2:30:10 LEADING:20 TRAILING:20 SLIDINGWINDOW:5:20 MINLEN:35 
##sangon_adapter.fa
##>PrefixPE/1
##AGATCGGAAGAGCACACGTCTGAAC
##>PrefixPE/2
##AGATCGGAAGAGCGTCGTGTAGGGA

###align bowtie2 with shell scripts
#bowtie2-build GCF_000240185.1_ASM24018v2_genomic.fna hs11286_index
#bowtie2 -x hs11286_index -1 kp_21_sangon_1P.fastq.gz -2 kp_21_sangon_2P.fastq.gz -S kp_21_sangon_mapped.sam
#bowtie2 -x hs11286_index -1 kp_28_sangon_1P.fastq.gz -2 kp_28_sangon_2P.fastq.gz -S kp_28_sangon_mapped.sam
#samtools view -bS kp_21_sangon_mapped.sam > kp_21_sangon_mapped.bam
#samtools view -bS kp_28_sangon_mapped.sam > kp_28_sangon_mapped.bam
#samtools sort -n kp_21_sangon_mapped.bam -o kp_21_sangon_mapped_sorted.bam
#samtools sort -n kp_28_sangon_mapped.bam -o kp_28_sangon_mapped_sorted.bam

##part 2
####featureCounts ignoreDup=F,countMultiMappingReads=F
##featureCounts
##library(Rsubread)
kp_21_exp <- featureCounts("kp_21_sangon_mapped_sorted.bam",annot.ext = "HS11286.gtf",
                                  isGTFAnnotationFile = T,GTF.featureType = "transcript",
                                  GTF.attrType = "Name",isPairedEnd = T,ignoreDup=F,
                                  requireBothEndsMapped=T,nthreads=4,countChimericFragments=F,
                                  countMultiMappingReads=F)
kp_28_exp <- featureCounts("kp_28_sangon_mapped_sorted.bam",annot.ext = "HS11286.gtf",
                                  isGTFAnnotationFile = T,GTF.featureType = "transcript",
                                  GTF.attrType = "Name",isPairedEnd = T,ignoreDup=F,
                                  requireBothEndsMapped=T,nthreads=4,countChimericFragments=F,
                                  countMultiMappingReads=F)

###collect counts
fc_21 <- data.frame(Gene_ID=rownames(kp_21_exp$counts),Pos=paste0(
  kp_21_exp$annotation$Chr,"[",kp_21_exp$annotation$Strand,"]",
  kp_21_exp$annotation$Start,"-",kp_21_exp$annotation$End),
  Length=kp_21_exp$annotation$Length,Count=kp_21_exp$counts[,1])
fc_28 <- data.frame(Gene_ID=rownames(kp_28_exp$counts),Pos=paste0(
  kp_28_exp$annotation$Chr,"[",kp_28_exp$annotation$Strand,"]",
  kp_28_exp$annotation$Start,"-",kp_28_exp$annotation$End),
  Length=kp_28_exp$annotation$Length,Count=kp_28_exp$counts[,1])

##TPM
fc_21$TPM <- ((fc_21$Count/fc_21$Length)*1000000)/
  (sum(fc_21$Count/fc_21$Length))
fc_28$TPM <- ((fc_28$Count/fc_28$Length)*1000000)/
  (sum(fc_28$Count/fc_28$Length))

##edgeR不过滤/或根据TPM>=5过滤
##先过滤TPM >=5，最后直接使用差异
#cts <- cts[unique(rownames(fc_28[fc_28$TPM>=5,]),
#                  rownames(fc_21[fc_21$TPM>=5,])),]

##选择不过滤，最后得出差异再过滤
library(edgeR)
cts <- data.frame(kp_21=fc_21$Count,kp_28=fc_28[rownames(fc_21),]$Count,
                  row.names=rownames(fc_21))
group=factor(c("kp_21","kp_28"),levels=c("kp_21","kp_28"))
y <- DGEList(cts,group=group)
y$samples$lib.size=colSums(y$counts)
y <- calcNormFactors(y,method="TMM")

##updated fc_sangon cpm rpkm normalized count
cpm_sangon <- data.frame(cpm(y))
fc_21$CPM <- cpm_sangon[rownames(fc_21),]$kp_21
fc_28$CPM <- cpm_sangon[rownames(fc_28),]$kp_28
#length
rpkm_sangon <- data.frame(rpkm(y,gene.length =
  c(fc_21[rownames(y$counts),]$Length,
    fc_28[rownames(y$counts),]$Length)))
fc_21$RPKM <- rpkm_sangon[rownames(fc_21),]$kp_21
fc_28$RPKM <- rpkm_sangon[rownames(fc_28),]$kp_28
#norm.count
fc_21$Norm.Count <- fc_21$Count/y$samples$norm.factors[1]
fc_28$Norm.Count <- fc_28$Count/y$samples$norm.factors[2]

##collection and print to file
Total_counts <- data.frame(row.names=rownames(fc_21),
                           Geneid=rownames(fc_21),
                           Pos=fc_21$Pos,
                           Length=fc_21$Length,
                           Counts_kp_21=fc_21$Count,
                           Counts_kp_28=fc_28[rownames(fc_21),]$Count,
                           CPM_kp_21=fc_21$CPM,
                           CPM_kp_28=fc_28[rownames(fc_21),]$CPM,
                           RPKM_kp_21=fc_21$RPKM,
                           RPKM_kp_28=fc_28[rownames(fc_21),]$RPKM,
                           TPM_kp_21=fc_21$TPM,
                           TPM_kp_28=fc_28[rownames(fc_21),]$TPM,
                           Norm.Count_kp_21=fc_21$Norm.Count,
                           Norm.Count_kp_28=fc_28[rownames(fc_21),]$Norm.Count
)
write.table(Total_counts,file="All_samples_count_statistic.txt",sep="\t",quote=F)
write.csv(Total_counts,file="All_samples_count_statistic.csv")

### cts count normalized by norm.factors and is used for DEGseq package analysis
library(DEGseq)
cts$kp_21_norm <- cts$kp_21/(y$samples$norm.factors[1])
cts$kp_28_norm <- cts$kp_28/(y$samples$norm.factors[2])

write.table(cts,file="cts_normalized_by_norm_factor.txt",
            sep="\t",row.names = T)
kp_21_cts <- readGeneExp(file="cts_normalized_by_norm_factor.txt",geneCol=1,valCol = 4)
kp_28_cts <- readGeneExp(file="cts_normalized_by_norm_factor.txt",geneCol=1,valCol = 5)
layout(matrix(c(1,2,3,4,5,6),3,2,byrow=T))
par(mar=c(2,2,2,2))
DEGexp(geneExpMatrix1 = kp_28_cts,geneCol1 = 1,expCol1 = 2,groupLabel1 = "kp_28_cts",
       geneExpMatrix2 = kp_21_cts,geneCol2 = 1,expCol2 = 2,groupLabel2 = "kp_21_cts",
       method="MARS",rawCount = F,thresholdKind=3,qValue=0.05,normalMethod = "none",
       outputDir="./kp_sangon_cts_norm_degseq_results")

##topGO analysis 
kp_score <- read.delim("./kp_sangon_cts_norm_degseq_results/output_score.txt",
                      header=T,sep="\t")
rownames(kp_score) <- kp_score$GeneNames

##选择后过滤TMP>=5
kp_score$kp_21_TPM <- fc_21[rownames(kp_score),]$TPM
kp_score$kp_28_TPM <- fc_28[rownames(kp_score),]$TPM

##log2.Fold_change.
DE_28vs21_up <- kp_score[kp_score$log2.Fold_change. > 1 & 
                           kp_score$Signature.q.value.Benjamini.et.al..1995....0.05.=="TRUE" &
                           kp_score$kp_21_TPM >= 5 & kp_score$kp_28_TPM >= 5,]
DE_28vs21_down <- kp_score[kp_score$log2.Fold_change. < -1 &
                             kp_score$Signature.q.value.Benjamini.et.al..1995....0.05.=="TRUE" &
                             kp_score$kp_21_TPM >= 5 & kp_score$kp_28_TPM >= 5,]

##log2.Fold_change..normalized
#DE_28vs21_up <- kp_score[kp_score$log2.Fold_change..normalized > 1 & 
#                          kp_score$Signature.q.value.Benjamini.et.al..1995....0.05.=="TRUE" &
#                           kp_score$kp_21_TPM >= 5 & kp_score$kp_28_TPM >= 5,]
#DE_28vs21_down <- kp_score[kp_score$log2.Fold_change..normalized < -1 &
#                          kp_score$Signature.q.value.Benjamini.et.al..1995....0.05.=="TRUE" &
#                            kp_score$kp_21_TPM >= 5 & kp_score$kp_28_TPM >= 5,]

##选择先过滤TPM>=5
#DE_28vs21_up <- kp_score[kp_score$log2.Fold_change. > 1 & 
#                          kp_score$Signature.q.value.Benjamini.et.al..1995....0.05.=="TRUE",]
#DE_28vs21_down <- kp_score[kp_score$log2.Fold_change. < -1 &
#                          kp_score$Signature.q.value.Benjamini.et.al..1995....0.05.=="TRUE",]

###Part 3
##topGO enrichment
library(topGO)
geneID2GO <- readMappings("HS11286_sangon_go.txt")
geneList_up <- as.factor(as.integer(rownames(cts) %in%
                                             DE_28vs21_up$GeneNames))
names(geneList_up) <- rownames(cts)
geneList_down <- as.factor(as.integer(rownames(cts) %in% 
                                        DE_28vs21_down$GeneNames))
names(geneList_down) <- rownames(cts)  
go_type <- c("MF","BP","CC")

##28 vs 21 high 构建富集GOdata数据
up_go <- list()
for(i in 1:length(go_type)){
  type=go_type[i]
  godata <- new("topGOdata",ontology=type,allGenes=geneList_up,
                description=paste("GOdata_up",type,sep="\t"),annot=annFUN.gene2GO,
                gene2GO=geneID2GO,nodeSize=1)
  ##renew the GOdata
  .geneList_up <- as.factor(as.integer(genes(godata) %in% sigGenes(godata)))
  names(.geneList_up) <- genes(godata)
  godata <- new("topGOdata", ontology=type,allGenes=.geneList_up,
                description=paste("GOdata_up",type,sep="\t"),annot=annFUN.gene2GO,
                gene2GO=geneID2GO,nodeSize=1)
  up_go[[i]] <- godata
}

#statistic <- c("classic","weight01","elim"), 富集检测
up_go_results <- list()
up_go_results_table <- list()
up_go_results_gentable <- list()
for(i in 1:length(up_go)){
  godata <- up_go[[i]]
  result <- runTest(godata,algorithm = "classic",statistic = "fisher")
  up_go_results_gentable[[i]] <- GenTable(godata,classic=result,orderBy="classic",ranksOf="classic",
                                                   topNodes=length(usedGO(godata)),numChar=50)
  up_go_results_gentable[[i]]$qvalue <- p.adjust(sort(score(result)),"BH")
  up_go_results_gentable[[i]] <- up_go_results_gentable[[i]][order(up_go_results_gentable[[i]]$qvalue),]
  up_go_results_table[[i]] <- up_go_results_gentable[[i]][1:30,]
  up_go_results_gentable[[i]]$Term <- Definition(up_go_results_gentable[[i]]$GO.ID)
  
  up_go_results_gentable[[i]]$Sig_Genes <- sapply(
    sapply(genesInTerm(godata,up_go_results_gentable[[i]]$GO.ID),function(x){
      sigGenes(godata)[sigGenes(godata) %in% x]
    }),function(y){paste(y,collapse = ",")})
  
  up_go_results_gentable[[i]]$All_Genes <- sapply(
    genesInTerm(godata,up_go_results_gentable[[i]]$GO.ID),
    function(x){paste(x,collapse = ",")})
  
  up_go_results[[i]] <- result
}

##28 vs 21 down 构建GOdata数据
down_go <- list()
for(i in 1:length(go_type)){
  type=go_type[i]
  godata <- new("topGOdata",ontology=type,allGenes=geneList_down,
                description=paste("GOdata_28vs21_l",type,sep="\t"),annot=annFUN.gene2GO,
                gene2GO=geneID2GO,nodeSize=1)
  ##renew the genelist
  .geneList_down <- as.factor(as.integer(genes(godata) %in% sigGenes(godata)))
  names(.geneList_down) <- genes(godata)
  godata <- new("topGOdata",ontology=type,allGenes=.geneList_down,
                description=paste("GOdata_down",type,sep="\t"),annot=annFUN.gene2GO,
                gene2GO=geneID2GO,nodeSize=1)
  down_go[[i]] <- godata
}

down_go_results <- list()
down_go_results_table <- list()
down_go_results_gentable <- list()                
for(i in 1:length(down_go)){
  godata <- down_go[[i]]
  result <- runTest(godata,algorithm = "classic",statistic = "fisher")
  down_go_results_gentable[[i]] <- GenTable(godata,classic=result,orderBy="classic",ranksOf="classic",
                                                   topNodes=length(usedGO(godata)),numChar=50)
  down_go_results_gentable[[i]]$qvalue <- p.adjust(sort(score(result)),"BH")
  down_go_results_gentable[[i]] <- down_go_results_gentable[[i]][order(down_go_results_gentable[[i]]$qvalue),]
  down_go_results_table[[i]] <- down_go_results_gentable[[i]][1:30,]
  down_go_results_gentable[[i]]$Term <- Definition(down_go_results_gentable[[i]]$GO.ID)
  
  down_go_results_gentable[[i]]$Sig_Genes <- sapply(
    sapply(genesInTerm(godata,down_go_results_gentable[[i]]$GO.ID),function(x){
      sigGenes(godata)[sigGenes(godata) %in% x]
      }),function(y){paste(y,collapse = ",")})
    
  down_go_results_gentable[[i]]$All_Genes <- sapply(
    genesInTerm(godata,down_go_results_gentable[[i]]$GO.ID),
    function(x){paste(x,collapse = ",")})

  down_go_results[[i]] <- result
}

##绘制GO 富集散点图,ggsave根据后缀判断类型(device)
library(ggplot2)
##创建富集结果输出目录
dir.create("./GO_enrichment_results")
for(i in 1:3){
  tmp=up_go_results_table[[i]]
  ##命名图片名称
  name=paste0("Kp_28vs21_Up","_",go_type[i],"_","Enrichment_Map")
  tmp$Annot_comb <- paste(tmp$GO.ID,tmp$Term,sep=" : ")
  tmp$qvalue <- as.numeric(tmp$qvalue)
  tmp$Significant <- as.numeric(tmp$Significant)
  tmp$Annot_comb <- factor(tmp$Annot_comb,levels = rev(tmp$Annot_comb))
  p<- ggplot(tmp,aes(qvalue,Annot_comb))+geom_point(aes(size=Significant,color=qvalue))+
    scale_color_gradient(low="red",high="green")+scale_x_reverse()+
    labs(color="Classic Fisher Qvalue",size="Significant Count",x="Classic Fisher Qvalue",
         y="GO Terms",title=name)+theme(plot.title=element_text(hjust = 0.5))+theme_bw()
  ggsave(paste0("./GO_enrichment_results/",name,".pdf"),plot=p,width=25,height=15,units = "cm")
  printGraph(up_go[[i]],up_go_results[[i]],
                 firstSigNodes = 10,useInfo = "all",pdfSW=F,
                 fn.prefix=paste0("./GO_enrichment_results/",name,"DAG"))
  write.table(up_go_results_gentable[[i]],file=paste0(
    "./GO_enrichment_results/",name,".xls"),sep="\t",quote=F,row.names = F)
} 

for(i in 1:3){
  tmp=down_go_results_table[[i]]
  name=paste0("Kp_28vs21_Down","_",go_type[i],"_","Enrichment_Map")
  tmp$Annot_comb <- paste(tmp$GO.ID,tmp$Term,sep=" : ")
  tmp$qvalue <- as.numeric(tmp$qvalue)
  tmp$Significant <- as.numeric(tmp$Significant)
  tmp$Annot_comb <- factor(tmp$Annot_comb,levels = rev(tmp$Annot_comb))
  p<- ggplot(tmp,aes(qvalue,Annot_comb))+geom_point(aes(size=Significant,color=qvalue))+
    scale_color_gradient(low="red",high="green")+scale_x_reverse()+
    labs(color="Classic Fisher Qvalue",size="Significant Count",x="Classic Fisher Qvalue",
         y="GO Terms",title=name)+theme(plot.title=element_text(hjust = 0.5))+theme_bw()
  ggsave(paste0("./GO_enrichment_results/",name,".pdf"),plot=p,width=25,height=15,units = "cm")
  printGraph(down_go[[i]],down_go_results[[i]],
             firstSigNodes = 10,useInfo = "all",pdfSW=F,
             fn.prefix=paste0("./GO_enrichment_results/",name,"DAG"))
  write.table(down_go_results_gentable[[i]],file=paste0(
    "./GO_enrichment_results/",name,".xls"),sep="\t",quote=F,row.names = F)
} 

##part 4 
##clusterProfiler kegg analysis
library(clusterProfiler)
##kegg_database <- search_kegg_organism("Klebsiella pneumoniae",by="scientific_name",
##                                      ignore.case = T)
##kpm
kegg_28vs21_m_h <- enrichMKEGG(gene=DE_28vs21_h$GeneNames,organism = "kpm",
                            pvalueCutoff = 0.05)
kegg_28vs21_m_l <- enrichMKEGG(gene=DE_28vs21_l$GeneNames,organism = "kpm",
                             pvalueCutoff = 0.05)
kegg_28vs21_h <- enrichKEGG(gene=DE_28vs21_h$GeneNames,organism = "kpm",
                               pvalueCutoff = 0.05)
kegg_28vs21_l <- enrichKEGG(gene=DE_28vs21_l$GeneNames,organism = "kpm",
                               pvalueCutoff = 0.05)

kp <- loadDb("/Users/carlos/.AnnotationHub/74476/org.Klebsiella_pneumoniae_subsp._pneumoniae_HS11286.eg.sqlite")
DE_down_dataframe <- select(kp,keys=as.vector(DE_down),columns=c("ENTREZID","SYMBOL"),keytype="SYMBOL")
ego_down_mf <- enrichGO(DE_down_dataframe$ENTREZID,OrgDb = kp,keyType = "ENTREZID",
                        ont="MF",readable = T)






  




