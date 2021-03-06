#' Identify regions data by a coverage filter and get a count matrix
#'
#' Given a set of un-filtered coverage data (see \link{fullCoverage}), create
#' candidate regions by applying a cutoff on the coverage values,
#' and obtain a count matrix where the number of rows corresponds to the number
#' of candidate regions and the number of columns corresponds to the number of 
#' samples. The values are the mean coverage for a given sample for a given 
#' region.
#' 
#' @param fullCov A list where each element is the result from 
#' \link{loadCoverage} used with \code{returnCoverage = TRUE}. Can be generated 
#' using \link{fullCoverage}. If \code{runFilter = FALSE}, then 
#' \code{returnMean = TRUE} must have been used.
#' @param cutoff Per base pair, at least one sample has to have coverage 
#' strictly greater than \code{cutoff} to be included in the result. This
#' argument is passed to \link{filterData} and must be non-NULL.
#' @param filter Has to be either \code{"one"} (default) or \code{"mean"}. In 
#' the first case, at least one sample has to have coverage above \code{cutoff}.
#' In the second case, the mean coverage has to be greater than \code{cutoff}.
#' This argument is passed to \link{filterData}.
#' @param maxRegionGap This determines the maximum number of gaps between two 
#' genomic positions to be considered part of the same candidate Differentially 
#' Expressed Region (candidate DER). This argument is passed to 
#' \link{findRegions}.
#' @param maxClusterGap This determines the maximum gap between candidate DERs. 
#' It should be greater than \code{maxRegionGap}. This argument is passed to
#' \link{findRegions}.
#' @param L The width of the reads used. This argument is passed to
#' \link{coverageToExon}.
#' @param totalMapped The total number of reads mapped for each sample. 
#' Providing this data adjusts the coverage to reads in \code{targetSize} 
#' library. By default, to reads per 80 million reads.
#' @param targetSize The target library size to adjust the coverage to. Used
#' only when \code{totalMapped} is specified.
#' @param mc.cores This argument is passed to \link[BiocParallel]{SnowParam} 
#' to define the number of \code{workers}. You should use at most one core per 
#' chromosome.
#' @param mc.outfile This argument is passed to \link[BiocParallel]{SnowParam} 
#' to specify the \code{outfile} for any output from the workers.
#' @param runFilter This controls whether to run \link{filterData} or not. If 
#' set to \code{FALSE} then \code{returnMean = TRUE} must have been used to 
#' create each element of \code{fullCov}.
#' @param verbose If \code{TRUE} basic status updates will be printed along the 
#' way.
#'
#' @return A list with one entry per chromosome. Then per chromosome, a list 
#' with two components.
#' \describe{
#' \item{regions }{ A set of regions based on the coverage filter cutoff as
#' returned by \link{findRegions}.}
#' \item{coverageMatrix }{  A matrix with the mean coverage by sample for each
#' candidate region.}
#' }
#'
#' @details This function uses several other \link{derfinder-package} 
#' functions. Inspect the code if interested.
#'
#' @author Leonardo Collado-Torres
#' @export
#'
#' @importMethodsFrom IRanges nrow '$<-'
#' @importFrom BiocParallel SnowParam SerialParam bpmapply
#'
#' @examples
#' library('IRanges')
#' x <- Rle(round(runif(1e4, max=10)))
#' y <- Rle(round(runif(1e4, max=10)))
#' z <- Rle(round(runif(1e4, max=10)))
#' fullCov <- list("chr21" = DataFrame(x, y, z))
#' regionMat <- regionMatrix(fullCov = fullCov, maxRegionGap = 10L, 
#'     maxClusterGap = 300L, L = 36)
#'
#' \dontrun{
#' ## You can alternatively use filterData() on fullCov to reduce the required
#' ## memory before using regionMatrix(). This can be useful when mc.cores > 1
#' filteredCov <- lapply(fullCov, filterData, returnMean=TRUE, filter='mean', 
#'     cutoff=5)
#' regionMat2 <- regionMatrix(filteredCov, maxRegionGap = 10L, 
#'     maxClusterGap = 300L, L = 36, runFilter=FALSE)
#' identical(regionMat2, regionMat)
#' }

regionMatrix <- function(fullCov, cutoff = 5, filter = "mean", 
    maxRegionGap = 0L, maxClusterGap = 300L, L, totalMapped = NULL,
    targetSize = 80e6, mc.cores = 1,
    mc.outfile = Sys.getenv('SGE_STDERR_PATH'), runFilter = TRUE,
    verbose = TRUE) {
        
    ## Have to filter by something
    stopifnot(!is.null(cutoff))
    
    ## fullCov has to be named
    stopifnot(!is.null(names(fullCov)))
    
    ## If filtering has been run, check that the information is there
    if(!runFilter) {
        if(!all(sapply(fullCov, function(x) { all(c("coverage", "position", "meanCoverage") %in% names(x)) })))
            stop("When 'runFilter' = FALSE, all the elements of 'fullCov' are expected to be the output from filterData(..., returnMean=TRUE) with some non-NULL 'cutoff'.")
    }
        
    ## Define args
    moreArgs <- list(cutoff = cutoff, filter = filter,
        maxRegionGap = maxRegionGap, maxClusterGap = maxClusterGap, L = L,
        totalMapped = totalMapped, targetSize = targetSize,
        runFilter = runFilter, verbose = verbose)
    
    ## Define cluster
    if(mc.cores > 1) {
        BPPARAM <- SnowParam(workers = mc.cores, outfile = mc.outfile)
    } else {
        BPPARAM <- SerialParam()
    }
        
    ## Get regions per chr
    bpmapply(.regionMatrixByChr, fullCov, names(fullCov), MoreArgs = moreArgs, 
        SIMPLIFY = FALSE, BPPARAM = BPPARAM)
}

.regionMatrixByChr <- function(covInfo, chr, cutoff, filter, maxRegionGap = 0L, 
    maxClusterGap = 300L, L, totalMapped, targetSize, runFilter, verbose) {
    
    if (verbose) 
        message(paste(Sys.time(), "regionMatrix: processing", chr))
        
    ## Filter by 'one' or 'mean' and get mean coverage
    if(runFilter) {
        if(all(c("coverage", "position") %in% names(covInfo))) {
            filt <- filterData(data = covInfo$coverage, cutoff = cutoff,
                filter = filter, returnMean = TRUE, returnCoverage = TRUE,
                totalMapped = totalMapped, targetSize = targetSize,
                verbose = verbose, index = covInfo$position)
        } else {
            filt <- filterData(data = covInfo, cutoff = cutoff, filter = filter,
                returnMean = TRUE, returnCoverage = TRUE,
                totalMapped = totalMapped, targetSize = targetSize,
                verbose = verbose)
        }
        
        ## Identify regions
        regs <- findRegions(position = filt$position, 
            fstats = filt$meanCoverage, chr = chr, cutoff = 0,
            maxRegionGap = maxRegionGap, maxClusterGap = maxClusterGap,
            verbose = verbose)
            
        ## Prepare for getRegionCoverage
        fullCovTmp <- list(filt)
    } else {        
        ## Identify regions
        regs <- findRegions(position = covInfo$position, 
            fstats = covInfo$meanCoverage, chr = chr, cutoff = 0,
            maxRegionGap = maxRegionGap, maxClusterGap = maxClusterGap,
            verbose = verbose)
        
        ## Prepare for getRegionCoverage
        fullCovTmp <- list(covInfo)
    }     
    
    ## Format appropriately
    names(regs) <- seq_len(length(regs))
    
    ## Prepare for getRegionCoverage
    names(fullCovTmp) <- chr
        
    ## Get region coverage    
    regionCov <- getRegionCoverage(fullCov = fullCovTmp, regions = regs, 
        totalMapped = NULL, mc.cores = 1, verbose = verbose)
        
    covMat <- lapply(regionCov, colSums)
    covMat <- do.call(rbind, covMat) / L

    ## Finish
    res <- list(regions = regs, coverageMatrix = covMat)
    return(res)
    
}