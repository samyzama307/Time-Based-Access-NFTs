(define-non-fungible-token time-access-nft uint)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-LISTING-EXISTS (err u102))
(define-constant ERR-WRONG-COMMISSION (err u103))
(define-constant ERR-NOT-FOUND (err u104))
(define-constant ERR-PAUSED (err u105))
(define-constant ERR-MINT-LIMIT (err u106))
(define-constant ERR-ACCESS-EXPIRED (err u107))
(define-constant ERR-ACCESS-NOT-STARTED (err u108))
(define-constant ERR-INVALID-TIME (err u109))

(define-constant ROYALTY-BPS u500)
(define-constant BPS-DENOM u10000)
(define-constant ERR-NOT-LISTED (err u110))
(define-constant ERR-NOT-ENOUGH-STX (err u111))

(define-constant ERR-BATCH-LIMIT (err u113))
(define-constant MAX-BATCH-SIZE u50)

(define-data-var last-token-id uint u0)
(define-data-var contract-paused bool false)

(define-map token-metadata 
    uint 
    {
        title: (string-ascii 50),
        description: (string-ascii 200),
        image: (string-ascii 200),
        start-block: uint,
        end-block: uint,
        creator: principal
    }
)

(define-map access-permissions
    {token-id: uint, user: principal}
    {granted: bool}
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? time-access-nft token-id))
)

(define-read-only (get-token-metadata (token-id uint))
    (map-get? token-metadata token-id)
)

(define-read-only (has-access (token-id uint) (user principal))
    (let (
        (metadata (unwrap! (get-token-metadata token-id) false))
        (current-block stacks-block-height)
    )
    (and
        (>= current-block (get start-block metadata))
        (<= current-block (get end-block metadata))
        (default-to false (get granted (map-get? access-permissions {token-id: token-id, user: user})))
    ))
)

(define-read-only (is-access-active (token-id uint))
    (match (get-token-metadata token-id)
        metadata (let (
            (current-block stacks-block-height)
        )
        (and
            (>= current-block (get start-block metadata))
            (<= current-block (get end-block metadata))
        ))
        false
    )
)

(define-read-only (get-access-window (token-id uint))
    (match (get-token-metadata token-id)
        metadata (ok {
            start-block: (get start-block metadata),
            end-block: (get end-block metadata),
            current-block: stacks-block-height,
            is-active: (is-access-active token-id)
        })
        (err ERR-NOT-FOUND)
    )
)

(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

(define-public (mint-time-access-nft 
    (recipient principal)
    (title (string-ascii 50))
    (description (string-ascii 200))
    (image (string-ascii 200))
    (start-block uint)
    (end-block uint)
)
    (begin
        (asserts! (not (var-get contract-paused)) ERR-PAUSED)
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (asserts! (> end-block start-block) ERR-INVALID-TIME)
        (let (
            (token-id (+ (var-get last-token-id) u1))
        )
        (try! (nft-mint? time-access-nft token-id recipient))
        (map-set token-metadata token-id {
            title: title,
            description: description,
            image: image,
            start-block: start-block,
            end-block: end-block,
            creator: tx-sender
        })
        (var-set last-token-id token-id)
        (ok token-id))
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-TOKEN-OWNER)
        (nft-transfer? time-access-nft token-id sender recipient)
    )
)

(define-public (grant-access (token-id uint) (user principal))
    (let (
        (token-owner (unwrap! (nft-get-owner? time-access-nft token-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender token-owner) ERR-NOT-TOKEN-OWNER)
    (map-set access-permissions {token-id: token-id, user: user} {granted: true})
    (ok true))
)

(define-public (revoke-access (token-id uint) (user principal))
    (let (
        (token-owner (unwrap! (nft-get-owner? time-access-nft token-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender token-owner) ERR-NOT-TOKEN-OWNER)
    (map-set access-permissions {token-id: token-id, user: user} {granted: false})
    (ok true))
)

(define-public (verify-access (token-id uint))
    (begin
        (asserts! (has-access token-id tx-sender) ERR-ACCESS-EXPIRED)
        (ok true)
    )
)

(define-public (extend-access (token-id uint) (new-end-block uint))
    (let (
        (token-owner (unwrap! (nft-get-owner? time-access-nft token-id) ERR-NOT-FOUND))
        (metadata (unwrap! (get-token-metadata token-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender token-owner) ERR-NOT-TOKEN-OWNER)
    (asserts! (> new-end-block (get end-block metadata)) ERR-INVALID-TIME)
    (map-set token-metadata token-id (merge metadata {end-block: new-end-block}))
    (ok true))
)

(define-public (pause-contract)
    (begin
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (var-set contract-paused true)
        (ok true)
    )
)

(define-public (unpause-contract)
    (begin
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (var-set contract-paused false)
        (ok true)
    )
)

(define-read-only (is-paused)
    (var-get contract-paused)
)


(define-map listings 
    uint 
    {seller: principal, price: uint}
)

(define-private (royalty-amount (price uint))
    (/ (* price ROYALTY-BPS) BPS-DENOM)
)

(define-read-only (get-listing (token-id uint))
    (map-get? listings token-id)
)

(define-public (list-for-sale (token-id uint) (price uint))
    (let (
        (token-owner (unwrap! (nft-get-owner? time-access-nft token-id) ERR-NOT-FOUND))
    )
    (asserts! (not (var-get contract-paused)) ERR-PAUSED)
    (asserts! (is-eq tx-sender token-owner) ERR-NOT-TOKEN-OWNER)
    (asserts! (is-none (map-get? listings token-id)) ERR-LISTING-EXISTS)
    (map-set listings token-id {seller: token-owner, price: price})
    (ok true))
)

(define-public (cancel-listing (token-id uint))
    (let (
        (listing (unwrap! (map-get? listings token-id) ERR-NOT-LISTED))
    )
    (asserts! (not (var-get contract-paused)) ERR-PAUSED)
    (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-TOKEN-OWNER)
    (map-delete listings token-id)
    (ok true))
)

(define-public (buy (token-id uint))
    (let (
        (listing (unwrap! (map-get? listings token-id) ERR-NOT-LISTED))
        (seller (get seller listing))
        (price (get price listing))
        (metadata (unwrap! (get-token-metadata token-id) ERR-NOT-FOUND))
        (creator (get creator metadata))
        (royalty (royalty-amount price))
        (seller-payment (- price royalty))
    )
    (asserts! (not (var-get contract-paused)) ERR-PAUSED)
    (asserts! (>= (stx-get-balance tx-sender) price) ERR-NOT-ENOUGH-STX)
    (try! (stx-transfer? royalty tx-sender creator))
    (try! (stx-transfer? seller-payment tx-sender seller))
    (try! (nft-transfer? time-access-nft token-id seller tx-sender))
    (map-delete listings token-id)
    (ok true))
)

(define-read-only (get-marketplace-info (token-id uint))
    (match (map-get? listings token-id)
        listing (ok {
            listed: true,
            seller: (get seller listing),
            price: (get price listing),
            royalty-amount: (royalty-amount (get price listing))
        })
        (ok {
            listed: false,
            seller: tx-sender,
            price: u0,
            royalty-amount: u0
        })
    )
)

(define-constant ERR-NO-STATS (err u112))

(define-map access-usage-stats
    {token-id: uint, user: principal}
    {
        total-verifications: uint,
        last-verified-block: uint,
        first-verified-block: uint
    }
)

(define-read-only (get-usage-stats (token-id uint) (user principal))
    (ok (default-to 
        {total-verifications: u0, last-verified-block: u0, first-verified-block: u0}
        (map-get? access-usage-stats {token-id: token-id, user: user})
    ))
)

(define-read-only (get-user-verification-count (token-id uint) (user principal))
    (ok (get total-verifications (default-to 
        {total-verifications: u0, last-verified-block: u0, first-verified-block: u0}
        (map-get? access-usage-stats {token-id: token-id, user: user})
    )))
)

(define-read-only (has-user-verified (token-id uint) (user principal))
    (is-some (map-get? access-usage-stats {token-id: token-id, user: user}))
)

(define-private (record-verification (token-id uint) (user principal))
    (let (
        (current-stats (map-get? access-usage-stats {token-id: token-id, user: user}))
        (current-block stacks-block-height)
    )
    (match current-stats
        stats (map-set access-usage-stats 
            {token-id: token-id, user: user}
            {
                total-verifications: (+ (get total-verifications stats) u1),
                last-verified-block: current-block,
                first-verified-block: (get first-verified-block stats)
            }
        )
        (map-set access-usage-stats 
            {token-id: token-id, user: user}
            {
                total-verifications: u1,
                last-verified-block: current-block,
                first-verified-block: current-block
            }
        )
    )
    (ok true))
)

(define-private (process-grant (user principal) (token-id uint))
    (begin
        (map-set access-permissions {token-id: token-id, user: user} {granted: true})
        token-id
    )
)

(define-private (process-revoke (user principal) (token-id uint))
    (begin
        (map-set access-permissions {token-id: token-id, user: user} {granted: false})
        token-id
    )
)

(define-public (batch-grant-access (token-id uint) (users (list 50 principal)))
    (let (
        (token-owner (unwrap! (nft-get-owner? time-access-nft token-id) ERR-NOT-FOUND))
        (users-count (len users))
    )
    (asserts! (is-eq tx-sender token-owner) ERR-NOT-TOKEN-OWNER)
    (asserts! (<= users-count MAX-BATCH-SIZE) ERR-BATCH-LIMIT)
    (ok (fold process-grant users token-id)))
)

(define-public (batch-revoke-access (token-id uint) (users (list 50 principal)))
    (let (
        (token-owner (unwrap! (nft-get-owner? time-access-nft token-id) ERR-NOT-FOUND))
        (users-count (len users))
    )
    (asserts! (is-eq tx-sender token-owner) ERR-NOT-TOKEN-OWNER)
    (asserts! (<= users-count MAX-BATCH-SIZE) ERR-BATCH-LIMIT)
    (ok (fold process-revoke users token-id)))
)

(define-private (check-user-access-helper (user-data {user: principal, token: uint}))
    {
        user: (get user user-data),
        has-access: (has-access (get token user-data) (get user user-data))
    }
)

(define-private (prepare-user-data (user principal) (result {token: uint, users: (list 50 {user: principal, token: uint})}))
    {
        token: (get token result),
        users: (unwrap-panic (as-max-len? (append (get users result) {user: user, token: (get token result)}) u50))
    }
)

(define-read-only (get-batch-access-status (token-id uint) (users (list 50 principal)))
    (let (
        (user-data-list (get users (fold prepare-user-data users {token: token-id, users: (list)})))
    )
    (ok (map check-user-access-helper user-data-list)))
)