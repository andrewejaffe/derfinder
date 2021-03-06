% Generated by roxygen2 (4.0.1): do not edit by hand
\name{regionMatrix}
\alias{regionMatrix}
\title{Identify regions data by a coverage filter and get a count matrix}
\usage{
regionMatrix(fullCov, cutoff = 5, filter = "mean", maxRegionGap = 0L,
  maxClusterGap = 300L, L, totalMapped = NULL, targetSize = 8e+07,
  mc.cores = 1, mc.outfile = Sys.getenv("SGE_STDERR_PATH"),
  runFilter = TRUE, verbose = TRUE)
}
\arguments{
\item{fullCov}{A list where each element is the result from
\link{loadCoverage} used with \code{returnCoverage = TRUE}. Can be generated
using \link{fullCoverage}. If \code{runFilter = FALSE}, then
\code{returnMean = TRUE} must have been used.}

\item{cutoff}{Per base pair, at least one sample has to have coverage
strictly greater than \code{cutoff} to be included in the result. This
argument is passed to \link{filterData} and must be non-NULL.}

\item{filter}{Has to be either \code{"one"} (default) or \code{"mean"}. In
the first case, at least one sample has to have coverage above \code{cutoff}.
In the second case, the mean coverage has to be greater than \code{cutoff}.
This argument is passed to \link{filterData}.}

\item{maxRegionGap}{This determines the maximum number of gaps between two
genomic positions to be considered part of the same candidate Differentially
Expressed Region (candidate DER). This argument is passed to
\link{findRegions}.}

\item{maxClusterGap}{This determines the maximum gap between candidate DERs.
It should be greater than \code{maxRegionGap}. This argument is passed to
\link{findRegions}.}

\item{L}{The width of the reads used. This argument is passed to
\link{coverageToExon}.}

\item{totalMapped}{The total number of reads mapped for each sample.
Providing this data adjusts the coverage to reads in \code{targetSize}
library. By default, to reads per 80 million reads.}

\item{targetSize}{The target library size to adjust the coverage to. Used
only when \code{totalMapped} is specified.}

\item{mc.cores}{This argument is passed to \link[BiocParallel]{SnowParam}
to define the number of \code{workers}. You should use at most one core per
chromosome.}

\item{mc.outfile}{This argument is passed to \link[BiocParallel]{SnowParam}
to specify the \code{outfile} for any output from the workers.}

\item{runFilter}{This controls whether to run \link{filterData} or not. If
set to \code{FALSE} then \code{returnMean = TRUE} must have been used to
create each element of \code{fullCov}.}

\item{verbose}{If \code{TRUE} basic status updates will be printed along the
way.}
}
\value{
A list with one entry per chromosome. Then per chromosome, a list
with two components.
\describe{
\item{regions }{ A set of regions based on the coverage filter cutoff as
returned by \link{findRegions}.}
\item{coverageMatrix }{  A matrix with the mean coverage by sample for each
candidate region.}
}
}
\description{
Given a set of un-filtered coverage data (see \link{fullCoverage}), create
candidate regions by applying a cutoff on the coverage values,
and obtain a count matrix where the number of rows corresponds to the number
of candidate regions and the number of columns corresponds to the number of
samples. The values are the mean coverage for a given sample for a given
region.
}
\details{
This function uses several other \link{derfinder-package}
functions. Inspect the code if interested.
}
\examples{
library('IRanges')
x <- Rle(round(runif(1e4, max=10)))
y <- Rle(round(runif(1e4, max=10)))
z <- Rle(round(runif(1e4, max=10)))
fullCov <- list("chr21" = DataFrame(x, y, z))
regionMat <- regionMatrix(fullCov = fullCov, maxRegionGap = 10L,
    maxClusterGap = 300L, L = 36)

\dontrun{
## You can alternatively use filterData() on fullCov to reduce the required
## memory before using regionMatrix(). This can be useful when mc.cores > 1
filteredCov <- lapply(fullCov, filterData, returnMean=TRUE, filter='mean',
    cutoff=5)
regionMat2 <- regionMatrix(filteredCov, maxRegionGap = 10L,
    maxClusterGap = 300L, L = 36, runFilter=FALSE)
identical(regionMat2, regionMat)
}
}
\author{
Leonardo Collado-Torres
}

