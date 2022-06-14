# Support onTokenTransfer for arbitrum token gateway
There are 2 ways(Single,Center) to implement the onTokenTransfer() for arbitrum token gateway.
One is to implement a specific for each usage(Single way). Another is implement a helper center, and dispatch each request using staticcall to diy their process logic(Center way).
