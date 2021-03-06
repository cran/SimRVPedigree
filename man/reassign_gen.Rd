% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ManipulatePed_Functions.R
\name{reassign_gen}
\alias{reassign_gen}
\title{Reassign generation number based on affected status}
\usage{
reassign_gen(ped_file)
}
\arguments{
\item{ped_file}{An object of class \code{ped}. A pedigree generated by \code{sim_ped} or \code{sim_RVped}, or an object created by the function \code{\link{new.ped}}.  See details.}
}
\value{
A \code{ped} object containing only affected members, obligate carriers, and founders with generation numbers reassigned among disease-affected relatives based on their most recent common ancestor, as described in details.
}
\description{
The \code{reassign_gen} function assigns generation numbers among affected family members so that generation 1 represents the most recent generation that a putative disease variant shared identical by descent (IBD), as defined in Thompson (2000), by affected members could have been introduced into the pedigree.
}
\details{
\emph{**\code{reassign_gen} cannot be applied to pedigrees that contain loops or inbreeding.**}

The \code{reassign_gen} function accepts a pedigree and reassigns generation numbers among disease-affected relatives so that generation 1 represents the generation of the most recent common ancestor of all disease-affected relatives.  We note that the individual in generation 1 could themselves be disease-affected, i.e. an individual can be considered their own ancestor.

For example, consider a family with 2 affected members.  If the disease-affected relatives are a parent and a child, the affected parent would be assigned generation 1, and the affected child generation 2.  However, if the disease-affected relatives are a pair of siblings, each is be assigned generation 2 since a common parent of the two is assumed to be a carrier of a latent susceptibility variant.  Similarly, if the disease-affected relatives are a pair of cousins, is assigned generation 3, since a common grandparent is the most recent common ancestor from whom they could have inherited a shared variant associated with the disease.

Users who wish to assign generation number based on affection status in pedigrees that have not been simulated with the \code{SimRVpedigree} package must create a ped object using \code{\link{new.ped}}.
}
\examples{
# Read in example pedigrees
data(EgPeds)
class(EgPeds)

# Create ped object
Bpeds <- new.ped(EgPeds)
summary(Bpeds)

# Reassign generation numbers in the first four pedigrees in EgPeds
Apeds <- lapply(seq_len(5), function(x){
                 reassign_gen(Bpeds[Bpeds$FamID == x, ])})
Apeds <- do.call(rbind, Apeds)

# Compare pedigrees before and after reassigning
# generation number based on affected status
par(mfrow = c(1, 2))
for (k in 1:5) {
  plot(subset(Bpeds, FamID == k), gen_lab = TRUE, plot_legend = FALSE)
  mtext(paste0("Ped", k, ": before generation reassignment", sep = ""),
        side = 3, line = 1.5)

  plot(subset(Apeds, FamID == k), gen_lab = TRUE, plot_legend = FALSE)
  mtext(paste0("Ped", k, ": after generation reassignment", sep = ""),
        side = 3, line = 1.5)
}
par(mfrow = c(1, 1))
}
\references{
Nieuwoudt, Christina and Jones, Samantha J and Brooks-Wilson, Angela and Graham, Jinko (2018). \emph{Simulating Pedigrees Ascertained for Multiple Disease-Affected Relatives}. Source Code for Biology and Medicine, 13:2.

Thompson, E. (2000). \emph{Statistical Inference from Genetic Data on Pedigrees.} NSF-CBMS Regional Conference Series in Probability and Statistics, 6, I-169.
}
\seealso{
\code{\link{new.ped}}
}
