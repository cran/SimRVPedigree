#' Initial checks to disqualify a pedigree from ascertainment.
#'
#'
#'
#' @inheritParams ascertain_ped
#'
#' @return Logical. If TRUE, pedigree is discarded.
#' @keywords internal
disqualify_ped <- function(ped_file, num_affected, ascertain_span, first_diagnosis, sub_criteria){
  #first we check if there are at least num_affected affecteds who experienced disease onset
  #prior to the end of the ascertainment span and after the first year that realiable
  #diagnoses could be made
  #next we check to see if at least one affected experienced disease-onet during
  #the ascertainment period.
  if (is.null(first_diagnosis)) {
    first_diagnosis <- min(ped_file$birthYr, na.rm = TRUE)
  }

  if (is.null(sub_criteria)) {
    return(length(which(ped_file$onsetYr <= ascertain_span[2] & ped_file$onsetYr >= first_diagnosis)) < num_affected |
             length(which(ped_file$onsetYr %in% ascertain_span[1]:ascertain_span[2])) < 1)
  } else (
    return(length(which(ped_file$onsetYr <= ascertain_span[2] & ped_file$onsetYr >= first_diagnosis)) < num_affected |
             length(which(ped_file$onsetYr %in% ascertain_span[1]:ascertain_span[2])) < 1 |
             length(which(ped_file$subtype == sub_criteria[[1]])) < sub_criteria[[2]])
  )


}

#' Choose a proband from the disease-affected relatives in a pedigree
#'
#' @param ped_file Pedigree simulated by \code{sim_ped}.
#' @inheritParams sim_RVped
#'
#' @return Pedigree with proband selected.
#' @keywords internal
#'
choose_proband = function(ped_file, num_affected, ascertain_span, first_diagnosis){
  #initialize proband ID variable
  ped_file$proband <- F

  #Gather info on affecteds
  A_ID <- ped_file[ped_file$affected,
                   which(colnames(ped_file) %in% c("onsetYr", "ID", "proband"))]
  A_ID <- A_ID[order(A_ID$onsetYr), ]

  #Eliminate affecteds who experienced onset after the end
  #of the ascertainment span or before reliable diagnoses could be made
  if (is.null(first_diagnosis)) {
    A_ID <- A_ID[which(A_ID$onsetYr <= ascertain_span[2]), ]
  } else {
    A_ID <- A_ID[which(A_ID$onsetYr <= ascertain_span[2] & A_ID$onsetYr >= first_diagnosis), ]
  }

  A_ID$proband <- ifelse(A_ID$onsetYr %in% ascertain_span[1]:ascertain_span[2], T, F)

  if (sum(A_ID$proband) == 1) {
    #In this scenario we have only 1 candidate proband
    #NOTE: sim_RVped has already checked to make sure
    #that there was another affected prior to this one
    ped_file$proband[ped_file$ID == A_ID$ID[A_ID$proband]] <- T

  } else if (sum(abs(A_ID$proband - 1)) > (num_affected - 1)) {
    #multiple available probands and the n-1 affected condition has already
    #been met by start of ascertainment period, so simply choose randomly
    #amongst available probands
    probandID <- sample(size = 1, x = A_ID$ID[A_ID$proband])
    ped_file$proband[ped_file$ID == probandID] <- T

  } else {
    #no affecteds before ascertainment period, must choose from among
    #the nth or greater to experience onset
    A_ID$proband[1:(num_affected - 1)] <- F
    #must write additional if statement here because of R's interesting
    #take on how sample should work when there is only one 1 to sample from....
    if (sum(A_ID$proband) == 1) {
      ped_file$proband[ped_file$ID == A_ID$ID[A_ID$proband]] <- T
    } else {
      probandID <- sample(size = 1, x = A_ID$ID[A_ID$proband])
      ped_file$proband[ped_file$ID == probandID] <- T
    }
  }

  return(ped_file)
}

#' Trim pedigree based on proband recall
#'
#' Primarily intended as an internal function, \code{trim_ped} chooses a proband and trims relatives based on the proband's probability of recalling his or her relatives.
#'
#' By default \code{recall_probs} is four times the kinship coefficient, as defined by Thompson (see references), between the proband and the probands relative, which results in a recall probability of \eqn{2^{-(n-1)}} for a relative of degree \eqn{n}. Alternatively, the user may specify a list of recall probabilities of length \eqn{l > 0}, in which case the first \emph{l-1} items in \code{recall_probs} are the respective proband recall probabilities for relatives of degree \emph{1, 2, ..., l-1}, and the \emph{l}th item in \code{recall_probs} is the proband's recall probability for all relatives of degree \strong{\emph{l} or greater}.  For example if \code{recall_probs = c(1)} all relatives will be recalled by the proband with probability 1.
#'
#'
#' Occasionally, a trimmed family member must be retained to ensure that the pedigree can be plotted.  When this occurs, family members who share a non-zero kinship coefficient with the proband are censored of all pertinent information, and will always have the following qualities:
#' \enumerate{
#'   \item availability status = 0
#'   \item affected status = NA
#'   \item birth year = NA
#'   \item onset year = NA
#'   \item death year = NA
#'   \item RR = NA
#' }
#'
#' Users who wish to use \code{trim_ped} for pedigrees not generated by \code{sim_ped} or \code{sim_RVped} must use \code{\link{new.ped}} to create an object of class \code{ped}.  The \code{ped} object \emph{must} contain the following variables for each pedigree member:
#' \tabular{lll}{
#' \strong{name} \tab \strong{type} \tab \strong{description} \cr
#' \code{FamID} \tab numeric \tab family identification number \cr
#' \code{ID} \tab numeric \tab individual identification number \cr
#' \code{dadID} \tab numeric \tab identification number of father \cr
#' \code{momID} \tab numeric \tab identification number of mother \cr
#' \code{sex} \tab numeric \tab gender identification; if male \code{sex = 0}, if female \code{sex = 1} \cr
#' \code{affected} \tab logical \tab disease-affection status: \cr
#' \code{proband} \tab logical \tab a proband identifier: \code{proband = TRUE} if the individual is the proband, and \code{FALSE} otherwise.\cr
#' \tab \tab \code{affected  = TRUE} if affected by disease , and \code{FALSE} otherwise, \cr
#' \code{birthYr} \tab numeric \tab the individual's birth year.\cr
#' \code{onsetYr} \tab numeric \tab the individual's disease onset year, when applicable.\cr
#' \code{deathYr} \tab numeric \tab the individual's death year, when applicable.\cr
#' \code{RR} \tab numeric \tab the individual's relative risk of disease. \cr
#' \code{available} \tab logical \tab availibility status; \cr
#' \tab\tab \code{available = TRUE} if available, and \code{FALSE} otherwise. \cr
#' }
#'
#' @inheritParams sim_RVped
#' @inheritParams censor_ped
#'
#'
#' @return \code{ped_trim} The trimmed pedigree.
#' @seealso \code{\link{sim_RVped}}, \code{\link{sim_ped}}, \code{\link{new.ped}}
#' @export
#'
#' @references Nieuwoudt, Christina and Jones, Samantha J and Brooks-Wilson, Angela and Graham, Jinko (2018). \emph{Simulating Pedigrees Ascertained for Multiple Disease-Affected Relatives}. Source Code for Biology and Medicine, 13:2.
#' @references Thompson, E. (2000). \emph{Statistical Inference from Genetic Data on Pedigrees.} NSF-CBMS Regional Conference Series in Probability and Statistics, 6, I-169.
#'
#' @importFrom kinship2 kinship
#' @importFrom stats runif
#'
#' @examples
#' #Read in example pedigree to trim
#' data(EgPeds)
#' egPeds <- new.ped(EgPeds)
#'
#' #plot example_ped using kinship2
#' plot(subset(egPeds, FamID == 1), location = "topright", cex = 0.85)
#' mtext("Original Pedigree", side = 3, line = 2)
#'
#'
#' ## Trim pedigree examples
#' # Illustrate the effect of various settings for recall_probs
#' Recall_Probabilities <- list(c(1),
#'                              c(1, 0.5),
#'                              c(1, 0.25, 0.1))
#'
#'
#' for (k in 1:length(Recall_Probabilities)) {
#'    set.seed(2)
#'    #trim pedigree
#'    TrimPed <- trim_ped(ped_file = subset(egPeds, FamID == 1),
#'                        recall_probs = Recall_Probabilities[[k]])
#'
#'    plot(TrimPed, location = "topright", cex = 0.85)
#'    mtext(paste0("recall_probs = (", sep = "",
#'                 paste(Recall_Probabilities[[k]], collapse = ", "), ')' ),
#'                 side = 3, line = 2 )
#' }
#'
#'
trim_ped = function(ped_file, recall_probs = NULL){

  if (!is.ped(ped_file)) {
    stop("\n \n Expecting a ped object. \n Please use new.ped to create an object of class ped.")
  }

  #issue error message if proband variable not supplied with single proband selected.
  if (!("proband" %in% colnames(ped_file))) {
    stop ('please supply a proband identification variable')
  } else if (sum(ped_file$proband) != 1){
    stop ('pedigree may not contain mulitple probands, please ensure that a single individual is designated as the proband ')
  }

  probandID <- ped_file$ID[ped_file$proband]

  #store info on marry-ins by ID
  marry_ins <- ped_file$ID[ped_file$available == FALSE]

  # generate a vector of Unif(0,1) RVs, to determine who is trimmed
  u <- runif(length(ped_file$ID))

  #calculate the kinship matrix for our pedigree
  kin_mat <- kinship(ped_file,
                     id = ped_file$ID,
                     dadid = ped_file$dadID,
                     momid = ped_file$momID)

  kin_proband <- kin_mat[, ped_file$ID == probandID]

  #if recall_probs have not been supplied just use 4*kinship coefficent
  if (is.null(recall_probs)) {
    # keep only those individuals for whom 4*kinship coefficent with the proband
    # is greater than runif(1).  This will result in keeping parents, offspring,
    # and siblings with probability 1

    ped_trim <- ped_file[4*kin_proband >= u, ]
  } else if (length(recall_probs) == 1 & sum(recall_probs) == 1) {
    #Fully ascertained pedigrees, no trimming needed
    ped_trim <- ped_file
  } else {
    # create rprobs, which will associate the recall probabilities
    # specified by the user with the appropriate individuals in the
    # pedigree based on their kinship coefficients.

    rprobs <- rep(NA, length(ped_file$ID))

    # set recall probability for proband to 1
    rprobs[kin_proband == 0.5] <- 1

    # set recall probability for marry-ins to 0
    # NOTE: we will re-add essential marry-ins
    # (i.e. those needed to create ped) at a later step
    rprobs[kin_proband == 0] <- 0

    # create a vector of kinship coefficients with the same length
    # as recall_probs, specified by the user
    kin_list <- 2^{-seq(from = 2, to = (length(recall_probs)+1), by = 1)}

    # use kinship coefficient to associate recall_prob with
    # appropriate family member
    for (i in 1:(length(kin_list)-1)) {
      rprobs[kin_proband == kin_list[i]] <- recall_probs[i]
    }
    rprobs[is.na(rprobs)] <- recall_probs[length(recall_probs)]

    #trim pedigree
    ped_trim <- ped_file[rprobs >= u, ]
  }

  # re-add individuals who cannot be recalled by proband
  # but who are required to create a complete pedigree
  d <- 0
  while (d == 0) {
    #find the dad IDs that are required but have been removed
    readd_dad <- find_missing_parent(ped_trim)

    #find the mom IDs that are required but have been removed
    readd_mom <- find_missing_parent(ped_trim, dad = FALSE)

    #check to see if we need to readd anyone
    if (length(c(readd_dad, readd_mom)) == 0) {
      d <- 1
    } else {
      #Now pull the rows containing the required parents from the original ped_file
      readd <- ped_file[ped_file$ID %in% c(readd_dad, readd_mom), ]

      #remove all of their simulated data, and mark unavailable
      if (nrow(readd) >= 1) {
        #If the variables birthYr, onsetYr, and deathYr
        #are included in ped_file mark these values as
        #NA for the unrecalled individuals
        if ("birthYr" %in% colnames(ped_file)) readd$birthYr <- NA
        if ("onsetYr" %in% colnames(ped_file)) readd$onsetYr <- NA
        if ("deathYr" %in% colnames(ped_file)) readd$deathYr <- NA
        readd$available <- F
        #readd$RR        <- NA
        readd$affected  <- ifelse(readd$ID %in% marry_ins, F, NA)
      }

      #add back to pedigree
      ped_trim = rbind(ped_trim, readd)
    }
  }

  return(ped_trim)
}

#' Check to see if a trimmed pedigree is ascertained.
#'
#' @inheritParams choose_proband
#'
#' @return Logical. If TRUE, pedigree is ascertained.
#' @keywords internal
ascertainTrim_ped <- function(ped_file, num_affected,
                              first_diagnosis = NULL, sub_criteria = NULL){

  #Gather the onset years for all affecteds, and for the proband.
  #For the pedigree to be ascertained we need to ensure that at least
  #num_affected - 1 relatives experienced disease-onset before the proband.
  #When the first_diagnosis option is used, we will need to ensure that
  #num_affected - 1 relatives experienced disease-onset before the proband AND
  #after the first diagnosis year.
  POyear <- ped_file$onsetYr[ped_file$proband]

  Oyears <- ped_file$onsetYr[ped_file$affected
                             & ped_file$available
                             & ped_file$proband == FALSE]
  if (!is.null(first_diagnosis)) {
    Oyears <- Oyears[which(Oyears >= first_diagnosis)]
  }

  #determine if there are an appropriate number of
  #individuals affected before the proband
  criteria_one <- sum(Oyears <= POyear) >= (num_affected - 1)

  #determine if there are still an appropriate number of
  #individuals affected by the subtype in sub_criteria
  if (is.null(sub_criteria)){
    criteria_two <- TRUE
  } else {
    criteria_two <- sum(ped_file$affected[which(ped_file$subtype == sub_criteria[[1]] & ped_file$available)]) >= sub_criteria[[2]]
  }
  ascertained <- criteria_one & criteria_two

  return(ascertained)
}

#' Determine if a pedigree is ascertained
#'
#' Intended priamrily as an internal function, \code{ascertain_ped} checks to see if a pedigree returned by \code{\link{sim_ped}} is ascertained.
#'
#' @inheritParams trim_ped
#' @inheritParams sim_RVped
#'
#' @return  A list containing the following data frames:
#' @return \code{ascertained} Logical.  Indicates if pedigree is ascertained.
#' @keywords internal
ascertain_ped <- function(ped_file, num_affected,
                          ascertain_span,
                          recall_probs = NULL,
                          first_diagnosis = NULL,
                          sub_criteria = NULL){

  # prior to sending the simulated pedigree to the trim function,
  # we check to see if it meets the required criteria for number of
  # affected.  If it does, we choose a proband from the available
  # candidates prior to sending it to the trim_ped function.
  if (disqualify_ped(ped_file, num_affected, ascertain_span, first_diagnosis, sub_criteria)) {
    ascertained <- FALSE
    return_ped = ped_file
  } else {
    #choose a proband
    pro_ped <- choose_proband(ped_file, num_affected, ascertain_span, first_diagnosis)

    # Now that we have a full pedigree that meets our conditions, we trim the
    # pedigree and check to see that the trimmed pedigree STILL meets our
    # conditions, we then update ascertained appropriately.
    ascertained_ped <- trim_ped(ped_file = pro_ped, recall_probs)

    ascertained <- ascertainTrim_ped(ped_file = ascertained_ped, num_affected, first_diagnosis, sub_criteria)
    return_ped = ascertained_ped
  }

  return(list(ascertain = ascertained,
              ped_file = return_ped))
}

#' Simulate a pedigree ascertained to contain multiple disease-affected relatives
#'
#' \code{sim_RVped} simulates a pedigree ascertained to contain multiple affected members, selects a proband, and trims the pedigree to contain only those individuals that are recalled by the proband.
#'
#' When \code{RV_founder = TRUE}, all simulated pedigrees will segregate a genetic susceptibility variant.  In this scenario, we assume that the variant is rare enough that it has been introduced by one founder, and we begin the simulation of the pedigree with this founder.  Alternatively, when \code{RV_founder = FALSE} we simulate the starting founder's causal variant status with probability \code{carrier_prob}.  When \code{RV_founder = FALSE} pedigrees may not segregate the genetic susceptibility variant.  The default selection is \code{RV_founder = FALSE}.  Additionally, we note that \code{sim_RVpedigree} is intended for rare causal variants; users will recieve a warning if \code{carrier_prob > 0.002}.
#'
#' We note that when \code{GRR = 1}, pedigrees do not segregate the causal variant regardless of the setting selected for \code{RVfounder}.  When the causal variant is introduced to the pedigree we transmit it from parent to offspring according to Mendel's laws.
#'
#' When simulating diseases with multiple subtypes \code{GRR} is a numeric list indicating the genetic-relative risk for each subtype specified in the \code{\link{hazard}} object supplied to \code{hazard_rates}.  For example, for a disease with two disease subtypes, if we set \code{GRR = c(20, 1)} individuals who inherit the causal variant are 20 times more likely than non-carriers to develop the first subtype and as likely as non-carriers to develop the second subtype.
#'
#' We begin simulating the pedigree by generating the year of birth, uniformly, between the years specified in \code{founder_byears} for the starting founder.  Next, we simulate this founder's life events using the \code{\link{sim_life}} function, and censor any events that occur after the study \code{stop_year}.  Possible life events include: reproduction, disease onset, and death. We continue simulating life events for any offspring, censoring events which occur after the study stop year, until the simulation process terminates.  We do not simulate life events for marry-ins, i.e. individuals who mate with either the starting founder or offspring of the starting founder.
#'
#' We do not model disease remission. Rather, we impose the restriction that individuals may only experience disease onset once, and remain affected from that point on.  If disease onset occurs then we apply the hazard rate for death in the affected population.
#'
#' \code{sim_RVped} will only return ascertained pedigrees with at least \code{num_affected} affected individuals.  That is, if a simulated pedigree does not contain at least \code{num_affected} affected individuals \code{sim_RVped} will discard the pedigree and simulate another until the condition is met.  We note that even for \code{num_affected = 2}, \code{sim_RVped} can be computationally expensive.  To simulate a pedigree with no proband, and without a minimum number of affected members use \code{\link{sim_ped}} instead of \code{sim_RVped}.
#'
#' When simulating diseases with multiple subtypes, users may wish to apply additional ascertainment criteria using the \code{sub_criteria} argument. When supplied, this argument allows users to impose numeric subtype-specific ascertainmet criteria. For example, if and \code{sub_criteria = list("HL", 1)} then at least 1 of the \code{num_affected} disease-affected relatives must be affected by subtype "HL" for the pedigree to be asceratained.  We note that the first entry of \code{sub_criteria}, i.e. the subtype label, must match the one of subtype labels in the hazards object supplied to \code{hazard_rates}.  See examples.
#'
#' Upon simulating a pedigree with \code{num_affected} individuals, \code{sim_RVped} chooses a proband from the set of available candidates.  Candidates for proband selection must have the following qualities:
#' \enumerate{
#'   \item experienced disease onset between the years specified by \code{ascertain_span},
#'   \item if less than \code{num_affected} - 1 individuals experienced disease onset prior to the lower bound of \code{ascertain_span}, a proband is chosen from the affected individuals, such that there were at least \code{num_affected} affected individuals when the pedigree was ascertained through the proband.
#' }
#'
#'
#' We allow users to specify the first year that reliable diagnoses can be made using the argument \code{first_diagnosis}.  All subjects who experience disease onset prior to this year are not considered when ascertaining the pedigree for a specific number of disease-affected relatives.  By default, \code{first_diagnosis = NULL} so that all affected relatives, recalled by the proband, are considered when ascertaining the pedigree.
#'
#' After the proband is selected, the pedigree is trimmed based on the proband's recall probability of his or her relatives.  This option is included to model the possibility that a proband either cannot provide a complete family history or that they explicitly request that certain family members not be contacted.  If \code{recall_probs} is missing, the default values of four times the kinship coefficient, as defined by Thompson, between the proband and his or her relatives are assumed.  This has the effect of retaining all first degree relatives with probability 1, retaining all second degree relatives with probability 0.5, retaining all third degree relatives with probability 0.25, etc.  Alternatively, the user may specify a list of length \eqn{l}, such that the first \eqn{l-1} items represent the respective recall probabilities for relatives of degree \eqn{1, 2, ... , l-1} and the \eqn{l^{th}} item represents the recall probability of a relative of degree \eqn{l} or greater. For example, if \code{recall_probs = c(1, 0.75, 0.5)}, then all first degree relatives (i.e. parents, siblings, and offspring) are retained with probability 1, all second degree relatives (i.e. grandparents, grandchildren, aunts, uncles, nieces and nephews) are retained with probability 0.75, and all other relatives are retained with probability 0.5. To simulate fully ascertained pedigrees, simply specify \code{recall_probs = c(1)}.
#'
#'
#' In the event that a trimmed pedigree fails the \code{num_affected} condition,  \code{sim_RVped} will discard that pedigree and simulate another until the condition is met.  For this reason, the values specified for \code{recall_probs} affect computation time.
#'
#' @param hazard_rates An object of class \code{hazard}, created by \code{\link{hazard}}.
#' @param GRR Numeric. The genetic relative-risk of disease, i.e. the relative-risk of disease for individuals who carry at least one copy of the causal variant.  Note: When simulating diseases with multiple subtypes \code{GRR} must contain one entry for each simulated subtype.  See details.
#' @param carrier_prob  Numeric.  The carrier probability for all causal variants with relative-risk of disease \code{GRR}.  By default, \code{carrier_prob}\code{ = 0.002}
#' @param RVfounder Logical.  Indicates if all pedigrees segregate the rare, causal variant.  By default, \code{RVfounder = FALSE} See details.
#' @param founder_byears Numeric vector of length 2.  The span of years from which to simulate, uniformly, the birth year for the founder who introduced the rare variant to the pedigree.
#' @param ascertain_span Numeric vector of length 2.  The year span of the ascertainment period.  This period represents the range of years during which the proband developed disease and the family would have been ascertained for multiple affected relatives.
#' @param num_affected Numeric vector.  The minimum number of disease-affected relatives required for ascertainment.
#' @param FamID Numeric. The family ID to assign to the simulated pedigree.
#' @param recall_probs Numeric. The proband's recall probabilities for relatives, see details.  If not supplied, the default value of four times kinship coefficient between the proband and the relative is used.
#' @param stop_year Numeric. The last year of study.  If not supplied, defaults to the current year.
#' @param NB_params Numeric vector of length 2. The size and probability parameters of the negative binomial distribution used to model the number of children per household.  By default, \code{NB_params}\code{ = c(2, 4/7)}, due to the investigation of Kojima and Kelleher (1962).
#' @param fert Numeric.  A constant used to rescale the fertility rate after disease-onset. By default, \code{fert = 1}.
#' @param first_diagnosis Numeric. The first year that reliable diagnoses can be obtained regarding disease-affection status.  By default, \code{first_diagnosis}\code{ = NULL} so that all diagnoses are considered reliable. See details.
#' @param sub_criteria List. Additional subtype criteria required for ascertainment.  The first item in \code{sub_criteria} is expected to be a character string indicating a subtype label and the second is a numeric entry indicating the minimum number of relatives affected by the identified subtype for ascertianment.   By default, \code{sub_criteria = NULL} so that no additional criteria is applied.  See details.
#'
#' @return  A list containing the following data frames:
#' @return \item{\code{full_ped} }{The full pedigree, prior to proband selection and trimming.}
#' @return \item{\code{ascertained_ped} }{The ascertained pedigree, with proband selected and trimmed according to proband recall probability.  See details.}
#' @export
#'
#' @references Nieuwoudt, Christina and Jones, Samantha J and Brooks-Wilson, Angela and Graham, Jinko (2018). \emph{Simulating Pedigrees Ascertained for Multiple Disease-Affected Relatives}. Source Code for Biology and Medicine, 13:2.
#' @references Ken-Ichi Kojima, Therese M. Kelleher. (1962), \emph{Survival of Mutant Genes}. The American Naturalist 96, 329-346.
#' @references Thompson, E. (2000). \emph{Statistical Inference from Genetic Data on Pedigrees.} NSF-CBMS Regional Conference Series in Probability and Statistics, 6, I-169.
#'
#'
#' @section See Also:
#' \code{\link{sim_ped}}, \code{\link{trim_ped}}, \code{\link{sim_life}}
#'
#' @examples
#' #Read in age-specific hazards
#' data(AgeSpecific_Hazards)
#'
#' #Simulate pedigree ascertained for multiple affected individuals
#' set.seed(2)
#' ex_RVped <- sim_RVped(hazard_rates = hazard(hazardDF = AgeSpecific_Hazards),
#'                       GRR = 20,
#'                       RVfounder = TRUE,
#'                       FamID = 1,
#'                       founder_byears = c(1900, 1905),
#'                       ascertain_span = c(1995, 2015),
#'                       num_affected = 2,
#'                       stop_year = 2017,
#'                       recall_probs = c(1, 1, 0))
#'
#' # Observe: ex_RVped is a list containing two ped objects
#' summary(ex_RVped)
#'
#' # The first is the original pedigree prior
#' # to proband selection and trimming
#' plot(ex_RVped[[1]])
#'
#' # The second is the ascertained pedigree which
#' # has been trimmed based on proband recall
#' plot(ex_RVped[[2]])
#' summary(ex_RVped[[2]])
#'
#'
#' # NOTE: by default, RVfounder = FALSE.
#' # Under this setting pedigrees segregate a causal
#' # variant with probability equal to carrier_prob.
#'
#'
#'
#' #---------------------------------------------------#
#' # Simulate Pedigrees with Multiple Disease Subtypes #
#' #---------------------------------------------------#
#' # Simulating pedigrees with multiple subtypes
#' # Import subtype-specific hazards rates for
#' # Hodgkin's lymphoma and non-Hodgkin's lymphoma
#' data(SubtypeHazards)
#' head(SubtypeHazards)
#'
#' my_hazards <- hazard(SubtypeHazards,
#'                      subtype_ID = c("HL", "NHL"))
#'
#'
#' # Simulate pedigree ascertained for at least two individuals
#' # affected by either Hodgkin's lymphoma or non-Hodgkin's lymphoma.
#' # Set GRR = c(20, 1) so that individuals who carry a causal variant
#' # are 20 times more likely than non-carriers to develop "HL" but have
#' # same risk as non-carriers to develop "NHL".
#' set.seed(45)
#' ex_RVped <- sim_RVped(hazard_rates = my_hazards,
#'                       GRR = c(20, 1),
#'                       RVfounder = TRUE,
#'                       FamID = 1,
#'                       founder_byears = c(1900, 1905),
#'                       ascertain_span = c(1995, 2015),
#'                       num_affected = 2,
#'                       stop_year = 2017,
#'                       recall_probs = c(1, 1, 0))
#'
#' plot(ex_RVped[[2]], cex = 0.6)
#'
#' # Note that we can modify the ascertainment criteria so that
#' # at least 1 of the two disease-affected relatives are affected by
#' # the "HL" subtype by supplying c("HL", 1) to the sub_criteria
#' # argument.
#' set.seed(69)
#' ex_RVped <- sim_RVped(hazard_rates = my_hazards,
#'                       GRR = c(20, 1),
#'                       RVfounder = TRUE,
#'                       FamID = 1,
#'                       founder_byears = c(1900, 1905),
#'                       ascertain_span = c(1995, 2015),
#'                       num_affected = 2,
#'                       stop_year = 2017,
#'                       recall_probs = c(1, 1, 0),
#'                       sub_criteria = list("HL", 1))
#'
#' plot(ex_RVped[[2]], cex = 0.6)
#'
sim_RVped = function(hazard_rates, GRR,
                     num_affected, ascertain_span,
                     FamID, founder_byears,
                     stop_year = NULL,
                     recall_probs = NULL,
                     carrier_prob = 0.002,
                     RVfounder = FALSE,
                     NB_params = c(2, 4/7),
                     fert = 1,
                     first_diagnosis = NULL,
                     sub_criteria = NULL){

  if(!(RVfounder %in% c(FALSE, TRUE))){
    stop ('Please set RVfounder to TRUE or FALSE.')
  }

  if (length(ascertain_span) != 2 | ascertain_span[1] >= ascertain_span[2]){
    stop ('please provide appropriate values for ascertain_span')
  }


  if (num_affected <= 0){
    stop ('num_affected < 1: To simulate pedigrees that do not consider the number of disease-affected relatives please use sim_ped.')
  }

  if (!is.null(sub_criteria)) {
    if (!is.numeric(sub_criteria[[2]])){
      stop('We expect the second item in sub_criteria to be a numeric entry that specifies the minimum number of individuals affected by the subtype.')
    }
    if (sub_criteria[[2]] > num_affected){
      stop('sub_criteria[[2]] > num_affected
           Please ensure that the second item in sub_criteria is less than or
           equal to the total number of individuals required for ascertainment.')
    }
    if (length(hazard_rates$subtype_ID) == 1) {
      stop('The hazard object supplied to hazard_rates does not include hazard rates for multiple disease subtypes.')
    }
    if (!(sub_criteria[[1]] %in% hazard_rates$subtype_ID)) {
      stop(paste0('Unidentified subtype \n The subtype specified in sub_criteria does not match any of the \n subtype labels in the hazard object supplied to hazards rates \n\n Subtype specifed in sub_criteria: ', sub_criteria[[1]], "\n subtypes identified in hazard object: ", paste0(hazard_rates$subtype_ID, collapse = ", "), "\n", sep = ""))
    }
  }

  if (!missing(recall_probs)) {
    if (any(recall_probs > 1) | any(recall_probs < 0) ){
      stop ('recall probabilities must be between 0 and 1')
    } else if (any(recall_probs != cummin(recall_probs))){
      warning('Nondecreasing values specified for recall_probs')
    } else if (recall_probs[1] != 1){
      warning('recall_probs: First-degree relatives may not be recalled.')
    }
  }

  if (is.null(stop_year)){
    stop_year <- as.numeric(format(Sys.Date(),'%Y'))
  }

  if (!is.null(first_diagnosis)) {
    if(first_diagnosis >= ascertain_span[1]) {
      stop("first_diagnosis >= ascertainment_span[1], \n Please re-define the ascertainment span so that all diagnoses within this time frame are considered reliable.")
    }
  }

  ascertained <- FALSE
  while(ascertained == FALSE){
    #generate pedigree
    fam_ped <- sim_ped(hazard_rates, GRR, FamID,
                       founder_byears, stop_year, carrier_prob,
                       RVfounder, NB_params, fert)


    #check to see if pedigree is ascertained
    check_pedigree <- ascertain_ped(ped_file = fam_ped,
                                    num_affected, ascertain_span,
                                    recall_probs, first_diagnosis,
                                    sub_criteria)

    #store updated pedigree
    ascertained <- check_pedigree[[1]]
    ascertained_ped <- check_pedigree[[2]]
  }

  #return original and trimmed pedigrees
  return(list(full_ped = fam_ped, ascertained_ped = ascertained_ped))
}
