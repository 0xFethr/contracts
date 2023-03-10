// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/utils/Counters.sol";
pragma solidity 0.8.14;

contract MainContract {

    using Counters for Counters.Counter;
    Counters.Counter public currPostID;
    Counters.Counter public userCount;
    address  payable immutable public owner;
    Post[] public allPosts;

    mapping(address => User) public allUsers;
    mapping(bytes32 => mapping(address =>bool))roleMapping;
    mapping(address => mapping(uint  => bool)) viewedPosts;

    bytes32 constant ADMIN = keccak256(abi.encodePacked("ADMIN"));
    bytes32 constant COOWNER = keccak256(abi.encodePacked("COOWNER"));

    error UserAlreadyPresent();
    error UserNotPresent();
    error NotOwner();
    error NotTheRequiredRole();
    error NotEnoughFunds();
    error AlreadyLiked();
    error AlreadyDisLiked();
    error AlreadySubscribed();

    struct User {
        address wallet;
        uint [] likedPosts;
        uint [] disLikedPosts;
        address[] subscribedUsers;
    }

    struct Post {
        address poster;
        uint id;
        uint upVotes;
        uint downVotes;
        uint views;
        string [] ipfsImages;
        string ipfsText;
        bool takenDown;
        
    }


    modifier onlyOwner {
        if(msg.sender != owner){
            revert NotOwner();
        }
        _;
    }

    modifier ownerOrCowner{
        if(!roleMapping[COOWNER][msg.sender] || msg.sender == owner){
            revert NotTheRequiredRole();
        }
        _;
    }

    modifier anyRole(){
        if(!roleMapping[COOWNER][msg.sender] || msg.sender != owner || !roleMapping[ADMIN][msg.sender]){
            revert NotTheRequiredRole();
        }
        _;
    }


    modifier userPresentCheck {
        if(allUsers[msg.sender].wallet != address(0)){
            revert UserAlreadyPresent();
        }
        _;
    }
    modifier userNotPresentCheck {
         if(allUsers[msg.sender].wallet == address(0)){
            revert UserNotPresent();
        }
        _;
    }

    modifier notAlreadyLiked(uint postID) {
        User memory user = allUsers[msg.sender];
        uint n  = user.likedPosts.length;
        for(uint i=0;i<n;++i){
            if(user.likedPosts[i] == postID){
                revert AlreadyLiked();
            }
        }
        _;

    }

    modifier notAlreadyDisLiked(uint postID) {
        User memory user = allUsers[msg.sender];
        uint n  = user.disLikedPosts.length;
        for(uint i=0;i<n;++i){
            if(user.disLikedPosts[i] == postID){
                revert AlreadyDisLiked();
            }
        }
        _;

    }
    modifier notAlreadySubscribed(address poster ) {
        address[] memory subs = getUser().subscribedUsers;
        uint n = subs.length;
        for(uint i=0;i<n;i++){
            if(poster == subs[i]){
                revert AlreadySubscribed();
            }
        }
        _;


    }

    constructor( ) payable {
        owner =payable(msg.sender);
    }
    // transfers the balance to the owner
    function transferAllToOwner() external onlyOwner {
        owner.call{value : address(this).balance}("");
    }
    // grants co owner role to the user (only the owner can call that )
    function grantCoOwnerRole(address to) public onlyOwner{
        roleMapping[COOWNER][to] = true;
    }
    // grants admin role to the user (only the owner or co owner can call this function )
    function grantAdminRole(address to) public ownerOrCowner {
        roleMapping[ADMIN][to] = true;
    }
    // create user 
    function createUser() public userPresentCheck{
        allUsers[msg.sender].wallet  = msg.sender;
        userCount.increment();
    }
    // deletes the user 
    function deleteUser() public userPresentCheck {
        allUsers[msg.sender].wallet = address(0);
        userCount.decrement();
    }
    // create post 
    function createPost(string[] memory _ipfsImages , string memory _ipfsText ) public userNotPresentCheck {
        allPosts.push(Post(msg.sender , currPostID.current() , 0 ,0 , 0 ,_ipfsImages , _ipfsText , false ));
        currPostID.increment();
    }
    // gets the user that calls tha function 
    function getUser() public view returns(User memory){
        return allUsers[msg.sender];
    }
    // gets the post with the given index
    function getPost(uint index) public view returns(Post memory){
        return allPosts[index];
    }
    // delete the given post 
    function deletePost(uint index) public {
        require(allPosts[index].poster == msg.sender , "You must be the owner of the Post");
        allPosts[index] = allPosts[allPosts.length - 1];
        allPosts.pop();
    }
    // gets all the posts that are valid and havent been taken down
    function getAllValidPosts() public view returns(Post [] memory){
        uint n  =allPosts.length;
        uint size=0;
        for(uint i=0;i<n;++i){
            if(!allPosts[i].takenDown)size++;
        }
        Post [] memory res = new Post[](n) ; 
        uint itr=0;
        for(uint i=0 ;i<n;++i){
            if(!allPosts[i].takenDown){
                res[itr] = allPosts[itr];
                itr++;
            }
        }
        return res;
    }
    // make the post invalid (admin  , co owner or owner can call this )
    function makePostInvalid(uint index) public anyRole{
        allPosts[index].takenDown = true;

    }
    // withdraws the funds and transfers to the calling address with the amount specified
    function withdrawFunds(uint amount) ownerOrCowner external {
        if(address(this).balance < amount){
            revert NotEnoughFunds();
        }
        payable(msg.sender).call{value : amount}("");
    }
    // add view to the post 
    function addView(uint _post ) external {
        viewedPosts[msg.sender][_post] = true;
        getPost(_post).views++;

    }
    // get all the posts that have been viewed by the user 
    function getAllViewedPostsByUser() external view returns(uint [] memory){
        uint count=0;
        for(uint i=0;i<currPostID.current();++i){
            if(!getPost(i).takenDown && viewedPosts[msg.sender][i]){
                count++;
            }
        }

        uint [] memory res = new uint[](count);
        uint itr =0;
        for(uint i=0;i<currPostID.current();++i){
            if(!getPost(i).takenDown && viewedPosts[msg.sender][i]){
                res[itr] = i;
            }
        }

        return res;
    }
    // like a post , it will automatically remove the dislike from the disliked list if the post was disliked 
    function likePost(uint postID) external userNotPresentCheck notAlreadyLiked(postID) {
        User storage user = allUsers[msg.sender];
        user.likedPosts.push(postID);
        getPost(postID).upVotes++;
        removeFromDisLiked(postID);
    }
    // remove the post from liked post 
    function removeFromLiked(uint postID) public userNotPresentCheck {
        User storage user  = allUsers[msg.sender];
        uint n = user.likedPosts.length;
        uint ind =0;
        bool flag = false;
        for(uint i=0;i<n;i++){
            if(user.likedPosts[i] == postID){
                flag = true;
                ind = i;
            }
        }
        if(flag){
            user.likedPosts[ind]= user.likedPosts[n-1];
            user.likedPosts.pop();

        }
        getPost(postID).upVotes--;


    }
    // dislikes the post and automatically removes it from the liked ones if it was 
    function disLikePost(uint postID) external  userNotPresentCheck notAlreadyDisLiked(postID){
        User storage user = allUsers[msg.sender];
        user.disLikedPosts.push(postID);
        getPost(postID).downVotes++;
        removeFromLiked(postID);

    }
    // remove post from the liked posts 
    function removeFromDisLiked(uint postID) public userNotPresentCheck {
        User storage user  = allUsers[msg.sender];
        uint n = user.disLikedPosts.length;
        uint ind =0;
        bool flag = false;
        for(uint i=0;i<n;i++){
            if(user.disLikedPosts[i] == postID){
                flag = true;
                ind = i;
            }
        }
        if(flag){
            user.disLikedPosts[ind]= user.disLikedPosts[n-1];
            user.disLikedPosts.pop();

        }
        getPost(postID).downVotes--;


    }
    // Subscribe to the User 
    function subscribeToPoster(address poster ) public userNotPresentCheck notAlreadySubscribed(poster)  {
        User storage user  =allUsers[msg.sender];
        user.subscribedUsers.push(poster);

    }

    function getLikedPosts() view external userNotPresentCheck returns(uint [] memory) {
        return getUser().likedPosts;
    }

    function getDisLikedPosts() view external userNotPresentCheck returns(uint [] memory) {
        return getUser().disLikedPosts;
    }

    function getSubscriberedUsers() view external userNotPresentCheck returns(address [] memory) {
        return getUser().subscribedUsers;
    }

    function consensusCheck(Post storage tempPost ) internal {
        if(tempPost.downVotes > userCount.current()/2 ) {
            tempPost.takenDown = true;
        }
    }

}