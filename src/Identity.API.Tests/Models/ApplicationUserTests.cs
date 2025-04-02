using Xunit;
using eShop.Identity.API.Models;

namespace eShop.Identity.API.Tests.Models;

public class ApplicationUserTests
{
    [Fact]
    public void ApplicationUser_Creation_ShouldSetProperties()
    {
        // Arrange
        var email = "test@example.com";
        var userName = "testuser";

        // Act
        var user = new ApplicationUser
        {
            Email = email,
            UserName = userName
        };

        // Assert
        Assert.Equal(email, user.Email);
        Assert.Equal(userName, user.UserName);
    }
} 