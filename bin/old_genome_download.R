library(biomartr)
library(data.table)
library(taxize)
args = commandArgs(trailingOnly=TRUE)
species <- args[1]
wd <- args[2]
species1 <- gsub("_", " ", species)
print("GENOME DOWNLOAD: Localtion for genome downloads:")
print(file.path(wd, "results", "downloaded_genomes"))
cat("\n\n")
delay <- 2 # delay in seconds to prevent hitting the NCBI API access limit
all_species <- unlist(strsplit(species, ","))

successful <- c()
failed <- c()
warnings <- c()
species_data <- data.frame(species=character(0), assembly= character(0), status= character(0), stringsAsFactors = F)

messagereader <- function (fun, ...) { # this function will capture the output from the genome download function
  a <- textConnection("me", "w", local=TRUE) # create a text connection, capturing all text. the first variable (me) will be containing the messages captured
  sink(a, type="message")
  res <- tryCatch (
    expr = {
      fun(...) # evaluate the genome download call
      message("MESSAGE READER: Species download finished")
    },
    error = function(cond){
      message("MESSAGE READER: An error occurred during download!") # message when an error occurs
      return(cond)
    },
    finally = {
      message("MESSAGE READER: trycatch done")
    }
  )
  sink(type="message")
  close(a)
  list(res, messages = me)
}


parse_download_message <- function(my_message, sp, sp_name) { # this function parses the download message from biomartr and decides what to do with it (successful/failed/error)
sp_sub <- gsub(" ", "_", sp)
sp_name <- gsub(" ", "_", sp_name)
#print(sp_sub)
#print(sp)
if (grepl("Unzipping downloaded file", my_message, fixed=T)) {
         print(paste("GENOME DOWNLOAD: Download for ", sp, " was successfull", sep=""))
         path <- file.path(wd, "results","downloaded_genomes",paste(sp_sub,"_genomic_genbank.fna",sep=""))
         species_data[nrow(species_data)+1, ] <<- c(sp_sub, path, "successful")
         successful <<- c(sp_name, successful)
         return
       } else if (grepl("no genome file could be found", my_message, fixed=T) == TRUE) {
         print(paste("GENOME DOWNLOAD: Download for ", sp, " failed", sep=""))
         species_data[nrow(species_data)+1, ] <<- c(sp_sub,"not_downloaded", "failed")
         failed <<- c(sp_name, failed)
         print("GENOME DOWNLOAD: Message from biomartr:")
         print(my_message)
         return
       } else if (!file.exists(file.path(wd, "results","downloaded_genomes",paste(sp_sub,"_genomic_genbank.fna",sep="")))){
         print(paste("GENOME DOWNLOAD: It seems no assembly for ", sp, " exists.", sep=""))
         species_data[nrow(species_data)+1, ] <<- c(sp_sub,"not_downloaded", "failed")
         failed <<- c(sp_name, failed)
         print("GENOME DOWNLOAD: Message from biomartr:")
         print(my_message)
         return
       } else {
         print(paste("GENOME DOWNLOAD: An unknown error occurred during genome download for ", sp, sep=""))
         species_data[nrow(species_data)+1, ] <<- c(sp_sub,"not_downloaded", "failed")
         failed <<- c(sp_name, failed)
         print("GENOME DOWNLOAD: Message from biomartr:")
         print(my_message)
         return
       }
}

get_genome_id_for_download <- function(sp) {

}

check_genome_availibilty <- function(sp, sp_name) {
 path <- file.path(wd,"results","downloaded_genomes",paste(sp,"_genomic_genbank.fna",sep=""))
 if (file.exists(path)) {
   print(paste("GENOME DOWNLOAD: File exists for ", sp, ". Will skip this species.", sep=""))
   cat("\n\n")
   successful <<- c(sp_name, successful)
   species_data[nrow(species_data)+1, ] <<- c(sp_name, path, "successful")
   return(TRUE)
 } else { return(FALSE) }
}

for (sp in all_species) {
  print(paste("----------------------- ",sp," ----------------------- ", sep=""))
  # first check if genome was already downloaded. In this case skip download.
  path <- file.path(wd,"results","downloaded_genomes",paste(sp,"_genomic_genbank.fna",sep=""))
  if (check_genome_availibilty(sp, sp) == TRUE) {
	next
  }
  sp_subbed <- gsub("_", " ", sp)
  
  #check if genome is available on NCBI
  print("GENOME DOWNLOAD: Checking genome availibility...")
  if (is.genome.available(db="genbank", organism=sp_subbed) == TRUE) {
    # get information on available genomes:
    Sys.sleep(delay) # to second delay to prevent hitting the NCBI API access limit
    genome_data <- is.genome.available(db="genbank", organism=sp_subbed, details=TRUE)
    # check how many genomes:
    Sys.sleep(delay) # to second delay to prevent hitting the NCBI API access limit
    if (nrow(genome_data)==1) {
       print(paste("GENOME DOWNLOAD: Found a single genome for ", sp, ". Will download this genome now.",sep=""))
       if (check_genome_availibilty(sp, sp) == TRUE) {
        next
       }
       mess <- messagereader(getGenome ,db="genbank", organism=sp_subbed, path=file.path(wd, "results","downloaded_genomes"), gunzip=T)
       Sys.sleep(delay) # to second delay to prevent hitting the NCBI API access limit
       my_message <- paste(mess$messages, collapse="\n")
       parse_download_message(my_message, sp_subbed, sp)
       #print(my_message)
    } else { # if there are more than one genomes available for this taxon proceed here
	if (length(unique(genome_data$taxid)) == 1) { #check if all assemblies have the same taxid
           print("GENOME DOWNLOAD: All available genomes have the same taxid. Will search for available reference genome...")
           if ("reference genome" %in% genome_data$refseq_category) { # reference genome found
              print(paste("GENOME DOWNLOAD: Reference genome is available for ", sp, ". Will download this", sep=""))
              accession <- genome_data[genome_data$refseq_category=="reference genome",]$assembly_accession[1]
              if (check_genome_availibilty(accession, sp) == TRUE) {
               next
              }
              mess <- messagereader(getGenome ,db="genbank", organism=accession, path=file.path(wd, "results","downloaded_genomes"), gunzip=T)
              my_message <- paste(mess$messages, collapse="\n")
              parse_download_message(my_message, accession, sp)
              next
           } else if ("representative genome" %in% genome_data$refseq_category) {
              print("GENOME DOWNLOAD: Representative genome found. Will download genome.")
              accession <- genome_data[genome_data$refseq_category=="representative genome",]$assembly_accession[1]
              if (check_genome_availibilty(accession, sp) == TRUE) {
               next
              }
              mess <- messagereader(getGenome ,db="genbank", organism=accession, path=file.path(wd, "results","downloaded_genomes"), gunzip=T)
              my_message <- paste(mess$messages, collapse="\n")
              print(sp)
	      parse_download_message(my_message, accession, sp)
              next
           }
           else {
              print(paste("GENOME DOWNLOAD: No genome is labeled as reference genome for ", sp, ". Will download the newest one.",sep=""))
              accession <- genome_data$assembly_accession[length(genome_data$seq_rel_date)][1]
              if (check_genome_availibilty(accession, sp) == TRUE) {
               next
              }
              mess <- messagereader(getGenome ,db="genbank", organism=accession, path=file.path(wd, "results","downloaded_genomes"), gunzip=T)
              my_message <- paste(mess$messages, collapse="\n")
              parse_download_message(my_message, accession, sp)
              next
           }  
        } else { # if there are multiple taxids proceed here
          print("GENOME DOWNLOAD: Multple taxids are present. Will try to resolve this...")
          Sys.sleep(delay)
	  class <- classification(sp_subbed, db="ncbi") #this should also work with underscores in the name!
          print("GENOME DOWNLOAD: Classification complete")
	  if (!("name" %in% colnames(class[[1]]))){
		print("GENOME DOWNLOAD: There is some ambiguity with this taxon. Will skip.")
	  	next
	  } 
	  #print(class)
          taxid <- class[[1]][class[[1]]$name == sp_subbed,]$id
	  found <- 0
          for (x in 1:length(unique(genome_data$taxid))) {
               #print(toString(unique(genome_data$taxid)[x]))
               if (taxid == toString(unique(genome_data$taxid)[x])) {
                  print(paste("GENOME DOWNLOAD: Correct taxid for ",sp, " seems to be ", taxid,". Will search for reference genome now", sep=""))
                  genome_data2 <- genome_data[genome_data$taxid==unique(genome_data$taxid)[x],]
		  if (is.na(genome_data2[genome_data2$refseq_category=="reference genome",]$assembly_accession[1]) == FALSE) { # check if reference genome or representative genome
                     print("GENOME DOWNLOAD: Reference genome found. Will download genome.")
                     accession <- genome_data2[genome_data2$refseq_category=="reference genome",]$assembly_accession[1]
                     if (check_genome_availibilty(accession, sp) == TRUE) {
                      break
                     }
                     mess <- messagereader(getGenome ,db="genbank", organism=accession, path=file.path(wd, "results","downloaded_genomes"), gunzip=T)
                     my_message <- paste(mess$messages, collapse="\n")
                     parse_download_message(my_message, accession, sp)  
                     found <- 1
                     break 
                  } else if (is.na(genome_data2[genome_data2$refseq_category=="representative genome",]$assembly_accession[1]) == FALSE) {
                     print("GENOME DOWNLOAD: Representative genome found. Will download genome.")
                     accession <- genome_data2[genome_data2$refseq_category=="representative genome",]$assembly_accession[1] 
                     if (check_genome_availibilty(accession, sp) == TRUE) {
                      break
                     }
                     mess <- messagereader(getGenome ,db="genbank", organism=accession, path=file.path(wd, "results","downloaded_genomes"), gunzip=T)
                     my_message <- paste(mess$messages, collapse="\n")
                     parse_download_message(my_message, accession, sp)
                     found <- 1
                     break
                  } else {
                     print("GENOME DOWNLOAD: Will download genome latest genome.")
                     accession <- genome_data2$assembly_accession[length(genome_data2$seq_rel_date)][1]
                     if (check_genome_availibilty(accession, sp) == TRUE) {
                      break
                     }
                     mess <- messagereader(getGenome ,db="genbank", organism=accession, path=file.path(wd, "results","downloaded_genomes"), gunzip=T)
                     my_message <- paste(mess$messages, collapse="\n")
                     #print(my_message)
                     parse_download_message(my_message, accession, sp)
                     found <- 1
                     break
                  }
               }
	  }
		# after the for loop for multiple taxids check if a genome was found:
		if (found == 0) {
		print("GENOME DOWNLOAD: Unfortunately I was unable to resolve this name based on its taxid. This can happen when only a genus name is provided.")
		print(paste("GENOME DOWNLOAD: Nothing downloaded for taxon: ", sp," with taxid: ",taxid, sep=""))
		species_data[nrow(species_data)+1, ] <- c(sp,"not_downloaded", "failed")
		failed <- c(sp, failed)
		}
		if (found == 1) {
		found <- 0
		}
        }  
    }
  } else {
  # it seems that this happens when a genome has been deposited only under the genus name but there also is a species genus available. Look at the algal set, where there are several cases like that. This could be better handeled and resolved permanently
  print(paste("GENOME DOWNLOAD:Genome for ", sp, " is not available on NCBI genbank and could therefore not be downloaded.", sep=""))
  species_data[nrow(species_data)+1, ] <- c(sp,"not_downloaded", "failed")
  failed <- c(sp, failed)
  }
cat("\n\n")
}
#species_data$assembly[species_data$status=="bli"]
#print(species_data)
#message("Completed species: ")
#message(successful)
#message("Failed species:")
#message(failed)
#message("There were warnings for:")
#message(warnings)
if (length(successful)>0) {
fwrite(list(species_data$species[species_data$status=="successful"]), file = file.path(wd, "results","downloaded_genomes", "successfully_downloaded.txt"))
}
if (length(failed)>0) {
  fwrite(list(species_data$species[species_data$status=="failed"]), file = file.path(wd, "results","downloaded_genomes", "not_downloaded.txt"))
}
write.csv(species_data, file.path(wd, "results","downloaded_genomes", "download_overview.txt"), row.names = F, quote=F)

